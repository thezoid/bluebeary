param(
    [bool]$LicensedOnly = $false
)

#force tls 1.2
[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$erroractionpreference = "continue"

function writeLog([string]$message, [string]$status = "info") {
    $timestamp = "$(get-date -Format "yyyyMMMdd@hh:mm:ss")"
    if (-not(test-path "c:\temp\logs")) {
        new-item -path "c:\temp\logs" -type directory | out-null
    }
    $logFile = "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-AzureADAuthMethods.log"
    $formattedMessage = "[$timestamp] $message"

    switch ($status.ToLower()) {
        "info"    { $color = "Blue"; $prefix = "*" }
        "success" { $color = "Green"; $prefix = "^" }
        "warning" { $color = "Yellow"; $prefix = "!" }
        "error"   { $color = "Red"; $prefix = "!!!" }
        default   { $color = "Blue"; $prefix = "*" }
    }

    $outputMessage = "$prefix$formattedMessage"
    write-host $outputMessage -ForegroundColor $color

    # Thread-safe log writing with retry
    $maxRetries = 5
    $retryDelayMs = 200
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            $outputMessage | Add-Content -Path $logFile -Force
            break
        } catch {
            if ($i -eq ($maxRetries - 1)) {
                write-host "Failed to write to log file after $maxRetries attempts: $_" -ForegroundColor Red
            } else {
                Start-Sleep -Milliseconds $retryDelayMs
            }
        }
    }
}

if (-not (Get-Module -Name Microsoft.Graph)) {
    Import-Module Microsoft.Graph
}

Connect-MgGraph -Scopes User.Read.All, UserAuthenticationMethod.Read.All, AuditLog.Read.All -NoWelcome

# Get the signed-in user's domain for dynamic path
$tenantDomain = (Get-MgOrganization).VerifiedDomains | Where-Object { $_.IsDefault } | Select-Object -ExpandProperty Name
if (-not $tenantDomain) {
    $tenantDomain = (Get-MgOrganization).VerifiedDomains | Select-Object -First 1 -ExpandProperty Name
}
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$tenantDomain-EntraIDUserAuthMethods.csv"
if (-not(test-path "c:\temp")) {
    new-item -path "c:\temp" -type directory | out-null
}
# Add new columns for Entra features
$csvHeader = "Name,Email,LastSignIn,DaysSinceLastSignIn,AccountEnabled,LastPasswordReset,DaysSinceLastPasswordReset,CreationDate,EmailLicensed,MfaEnabled,SecureMfaEnabled,Password,Phone,MicrosoftAuthenticator,FIDO2,WindowsHello,EmailMethod,SoftwareOATH,TemporaryAccessPass,"
$csvHeader | Out-File $outpath -Encoding UTF8

$users = Get-MgUser -All -Select "displayName,accountEnabled,UserPrincipalName,lastPasswordChangeDateTime,lastSignInDateTime,signinactivity,CreatedDateTime"
$count = 0
$startTime = get-date

# Helper: Check if user has an active Exchange Online (email) license
function HasActiveEmailLicense($userId) {
    $exchangePlanIds = @(
        "e2d4d3c3-1237-4a6c-9b3a-410a2b2fd2e6", # EXCHANGE_S_STANDARD (Plan 1)
        "4b9405b0-7788-4568-add1-99614e613b69", # EXCHANGE_S_ENTERPRISE (Plan 2)
        "c7df2760-2c81-4ef7-b578-5b5392b571df", # EXCHANGE_S_FOUNDATION (Kiosk)
        "33c27c18-402a-4d2a-bf2c-20736c571d1f", # EXCHANGE_S_ENTERPRISE (E1)
        "efb0351d-3b08-4503-993d-383af8de41e3", # EXCHANGE_S_ENTERPRISE (E3)
        "5b6abf1a-4362-4b26-8b5f-44d11d1c9077", # EXCHANGE_S_ENTERPRISE (E5)
        "c7699d2e-19aa-44de-8edf-1736da088ca1", # EXCHANGE_S_B_P2 (Business Basic)
        "e95bec33-7c88-4a70-8e19-b10bd9d0c6b6", # EXCHANGE_S_B_P1 (Business Standard)
        "c52ea49f-fe5d-4e95-93ba-1de91d380f89"  # EXCHANGE_S_B_P3 (Business Premium)
    )
    try {
        $licenseDetails = Get-MgUserLicenseDetail -UserId $userId
        foreach ($license in $licenseDetails) {
            foreach ($plan in $license.ServicePlans) {
                if ($exchangePlanIds -contains $plan.ServicePlanId -and $plan.ProvisioningStatus -eq "Success") {
                    return $true
                }
            }
        }
    } catch {
        writeLog "Failed to get license details for $userId`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
    }
    return $false
}

# Helper: Retry wrapper for Get-MgUserAuthenticationMethod
function Get-AuthMethodsWithRetry {
    param(
        [Parameter(Mandatory=$true)][string]$UserId,
        [int]$MaxRetries = 5,
        [int]$InitialDelaySeconds = 5
    )
    $attempt = 0
    $delay = $InitialDelaySeconds
    while ($attempt -lt $MaxRetries) {
        try {
            return Get-MgUserAuthenticationMethod -UserId $UserId -ErrorAction Stop
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg -match "Too Many Requests" -or $errMsg -match "429") {
                writeLog "Too Many Requests for $UserId. Attempt $($attempt+1) of $MaxRetries. Retrying in $delay seconds..." "warning"
                Start-Sleep -Seconds $delay
                $attempt++
                $delay = [Math]::Min($delay * 2, 60)
                continue
            } else {
                throw $_
            }
        }
    }
    throw "Too many retries for $UserId. Aborting."
}

$data = @()
foreach ($user in $users) {
    $count++
    writeLog "[$($count)/$($users.count)] checking $($user.UserPrincipalName) [$($user.id)]" "info"

    $result = [ordered]@{
        Name                   = $user.DisplayName
        Email                  = $user.UserPrincipalName
        Password               = ""
        Phone                  = ""
        MicrosoftAuthenticator = ""
        FIDO2                  = ""
        WindowsHello           = ""
        EmailMethod            = ""
        SoftwareOATH           = ""
        TemporaryAccessPass    = ""
        LastSignIn             = ""
        DaysSinceLastSignIn    = ""
        MfaEnabled             = ""
        SecureMfaEnabled       = ""
        AccountEnabled         = ""
        LastPasswordReset      = ""
        DaysSinceLastPasswordReset = ""
        CreationDate           = ""
        EmailLicensed          = ""
    }

    # Check for active email license before proceeding, if enabled
    $hasEmailLicense = $false
    if ($LicensedOnly) {
        if (-not (HasActiveEmailLicense $user.Id)) {
            $result.EmailLicensed = "No"
            writeLog "Skipping $($user.UserPrincipalName) - no active email license." "warning"
            continue
        } else {
            $hasEmailLicense = $true
        }
    } else {
        if (HasActiveEmailLicense $user.Id) {
            $hasEmailLicense = $true
        }
    }
    $result.EmailLicensed = if ($hasEmailLicense) { "Yes" } else { "No" }

    try {
        $authmethods = Get-AuthMethodsWithRetry -UserId $user.Id
    }
    catch {
        $errMsg = $_.Exception.Message
        if (($_ -and $_.ErrorDetails -and $_.ErrorDetails.Message -match "More than one users found") -or
            ($errMsg -and $errMsg -match "More than one users found")) {
            writeLog "Multiple users found for $($user.UserPrincipalName). Attempting to process all matching accounts." "warning"
            try {
                $matchingUsers = Get-MgUser -Filter "userPrincipalName eq '$($user.UserPrincipalName)'"
                foreach ($muser in $matchingUsers) {
                    writeLog "Processing account: $($muser.UserPrincipalName)" "info"
                    try {
                        $authmethods = Get-AuthMethodsWithRetry -UserId $muser.Id
                        foreach ($method in $authmethods) {
                            $odataType = $method.AdditionalProperties['@odata.type']
                            switch ($odataType) {
                                "#microsoft.graph.passwordAuthenticationMethod" {
                                    $result.Password = "Yes"
                                }
                                "#microsoft.graph.phoneAuthenticationMethod" {
                                    $phone = $method.AdditionalProperties['phoneNumber']
                                    $type = $method.AdditionalProperties['phoneType']
                                    $sms = $method.AdditionalProperties['smsSignInState']
                                    $result.Phone = "Number: $phone; Type: $type; SMS: $sms"
                                }
                                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                                    $device = $method.AdditionalProperties['displayName']
                                    $version = $method.AdditionalProperties['phoneAppVersion']
                                    $tag = $method.AdditionalProperties['deviceTag']
                                    $result.MicrosoftAuthenticator = "Device: $device; Version: $version; Tag: $tag"
                                }
                                "#microsoft.graph.fido2AuthenticationMethod" {
                                    $device = $method.AdditionalProperties['displayName']
                                    $created = $method.AdditionalProperties['createdDateTime']
                                    $aaguid = $method.AdditionalProperties['aaGuid']
                                    $result.FIDO2 = "Device: $device; Created: $created; AAGUID: $aaguid"
                                }
                                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                                    $device = $method.AdditionalProperties['displayName']
                                    $created = $method.AdditionalProperties['createdDateTime']
                                    $keyStrength = $method.AdditionalProperties['keyStrength']
                                    $result.WindowsHello = "Device: $device; Created: $created; KeyStrength: $keyStrength"
                                }
                                "#microsoft.graph.emailAuthenticationMethod" {
                                    $email = $method.AdditionalProperties['emailAddress']
                                    $result.EmailMethod = "Address: $email"
                                }
                                "#microsoft.graph.softwareOathAuthenticationMethod" {
                                    $result.SoftwareOATH = "Yes"
                                }
                                default {
                                    writeLog -message "Unknown authentication method type for $($user.UserPrincipalName): $odataType" -status "warning"
                                }
                            }
                        }
                        $data += [PSCustomObject]$result
                    }
                    catch {
                        writeLog "Failed to process account: $($muser.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                    }
                }
            }
            catch {
                writeLog "Failed to retrieve matching accounts for $($user.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
            }
            continue
        } else {
            writeLog "Failed to get auth methods for $($user.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
        }
        continue
    }

    # Check if the user is enabled
    try{
        $result.AccountEnabled = $user.accountEnabled
    }catch{
        $result.AccountEnabled = "Not available"
        writeLog "Failed to get account enabled status for $($user.UserPrincipalName): $_" "warning"
    }
    # Get last sign-in time
    try {
        $lastSignIn = $user.SignInActivity.LastSignInDateTime
        $result.LastSignIn = if (!$lastSignIn) { "Not available" } else { $lastSignIn }
        $result.DaysSinceLastSignIn = if ($lastSignIn) { [int]((Get-Date) - [datetime]$lastSignIn).TotalDays } else { "" }
    } catch {
        $result.LastSignIn = "Not available"
        $result.DaysSinceLastSignIn = ""
        writeLog "Failed to get last sign-in for $($user.UserPrincipalName): $_" "warning"
    }
    # Add Entra features
    try {
        $lastPwdReset = $user.lastPasswordChangeDateTime
        $result.LastPasswordReset = if (!$lastPwdReset) { "Not Available" } else { $lastPwdReset }
        $result.DaysSinceLastPasswordReset = if ($lastPwdReset) { [int]((Get-Date) - [datetime]$lastPwdReset).TotalDays } else { "" }
    } catch {
        $result.LastPasswordReset = "Not Available"
        $result.DaysSinceLastPasswordReset = ""
        writeLog "Failed to get last password reset for $($user.UserPrincipalName): $_" "warning"
    }
    try {
        $result.CreationDate = if (!$user.CreationDate) { "Not Available" } else { $user.CreatedDateTime }
    } catch {
        $result.CreationDate = "Not Available"
        writeLog "Failed to get creation date for $($user.UserPrincipalName): $_" "warning"
    }

    # Track MFA methods
    $hasAnyMfa = $false
    $hasSecureMfa = $false

    foreach ($method in $authmethods) {
        $odataType = $method.AdditionalProperties['@odata.type']
        switch ($odataType) {
            "#microsoft.graph.passwordAuthenticationMethod" {
                $result.Password = "Yes"
            }
            "#microsoft.graph.phoneAuthenticationMethod" {
                $phone = $method.AdditionalProperties['phoneNumber']
                $type = $method.AdditionalProperties['phoneType']
                $sms = $method.AdditionalProperties['smsSignInState']
                $result.Phone = "Number: $phone; Type: $type; SMS: $sms"
                $hasAnyMfa = $true
            }
            "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                $device = $method.AdditionalProperties['displayName']
                $version = $method.AdditionalProperties['phoneAppVersion']
                $tag = $method.AdditionalProperties['deviceTag']
                $result.MicrosoftAuthenticator = "Device: $device; Version: $version; Tag: $tag"
                $hasAnyMfa = $true
                $hasSecureMfa = $true
            }
            "#microsoft.graph.fido2AuthenticationMethod" {
                $device = $method.AdditionalProperties['displayName']
                $created = $method.AdditionalProperties['createdDateTime']
                $aaguid = $method.AdditionalProperties['aaGuid']
                $result.FIDO2 = "Device: $device; Created: $created; AAGUID: $aaguid"
                $hasAnyMfa = $true
                $hasSecureMfa = $true
            }
            "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                $device = $method.AdditionalProperties['displayName']
                $created = $method.AdditionalProperties['createdDateTime']
                $keyStrength = $method.AdditionalProperties['keyStrength']
                $result.WindowsHello = "Device: $device; Created: $created; KeyStrength: $keyStrength"
                $hasAnyMfa = $true
            }
            "#microsoft.graph.emailAuthenticationMethod" {
                $email = $method.AdditionalProperties['emailAddress']
                $result.EmailMethod = "Address: $email"
            }
            "#microsoft.graph.softwareOathAuthenticationMethod" {
                $result.SoftwareOATH = "Yes"
                $hasAnyMfa = $true
            }
            "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                $result.TemporaryAccessPass = "Yes"
                $hasAnyMfa = $true
            }
            default {
                writeLog -message "Unknown authentication method type for $($user.UserPrincipalName): $odataType" -status "warning"
            }
        }
    }

    $result.MfaEnabled = if ($hasAnyMfa) { "Yes" } else { "No" }
    $result.SecureMfaEnabled = if ($hasSecureMfa) { "Yes" } else { "No" }

    $data += [PSCustomObject]$result
}

# Check if $data is null before exporting
if ($null -ne $data) {
    $data | ForEach-Object { Write-Host $_ }
    $data | Export-Csv -Path $outpath -NoTypeInformation -Append
} else {
    writeLog "No data to export. The script did not process any users." "warning"
}

writeLog "Completed in: $(New-TimeSpan -start $startTime -end (get-date))" "success"


