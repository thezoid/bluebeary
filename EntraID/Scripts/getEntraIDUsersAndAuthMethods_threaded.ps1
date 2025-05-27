#force tls 1.2
[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$erroractionpreference = "continue"

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "This script requires PowerShell 7.0 or later. Please upgrade your PowerShell version."
}

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
    try {
        $outputMessage | Out-File $logFile -Append
    } catch {
        write-host "Failed to write to log file: $_" -ForegroundColor Red
    }
}

#import/install modules
#install-module Microsoft.Graph.users -scope currentuser -Force
#install-module Microsoft.Graph.Identity.Signins -scope currentuser  -Force
import-module Microsoft.Graph.users
import-module Microsoft.Graph.Identity.Signins
Connect-MgGraph -Scopes User.Read.All, UserAuthenticationMethod.Read.All
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-EntraIDUserAuthMethods.csv"
if (-not(test-path "c:\temp")) {
    new-item -path "c:\temp" -type directory | out-null
}
"Name,Email,Auth Methods" | out-file $outpath
$users = Get-MgUser -All
$startTime = get-date

# Ensure PowerShell version supports -Parallel
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "This script requires PowerShell 7.0 or later to use the -Parallel feature."
}

$data = $users | ForEach-Object -Parallel {
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
        try {
            $outputMessage | Out-File $logFile -Append
        } catch {
            write-host "Failed to write to log file: $_" -ForegroundColor Red
        }
    }

    writeLog "checking $($_.UserPrincipalName)" "info"

    try {
        $authmethods = Get-MgUserAuthenticationMethod -UserId $_.UserPrincipalName
    }
    catch {
        if ($_.ErrorDetails.Message -match "More than one users found") {
            writeLog "Multiple users found for $($_.UserPrincipalName). Attempting to process all matching accounts." "warning"
            try {
                # Retrieve all matching accounts
                $matchingUsers = Get-MgUser -Filter "userPrincipalName eq '$($_.UserPrincipalName)'"
                foreach ($user in $matchingUsers) {
                    writeLog "Processing account: $($user.UserPrincipalName)" "info"
                    try {
                        $authmethods = Get-MgUserAuthenticationMethod -UserId $user.Id
                        # Process auth methods for this account
                        $authMethodsList = @()
                        foreach ($method in $authmethods) {
                            $odataType = $method.AdditionalProperties['@odata.type']
                            $details = switch ($odataType) {
                                "#microsoft.graph.passwordAuthenticationMethod" {
                                    "Password (Created: $($method.AdditionalProperties['createdDateTime']))"
                                }
                                "#microsoft.graph.phoneAuthenticationMethod" {
                                    "Phone (Number: $($method.AdditionalProperties['phoneNumber']), Type: $($method.AdditionalProperties['phoneType']), SMS Sign-In: $($method.AdditionalProperties['smsSignInState']))"
                                }
                                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                                    "Microsoft Authenticator (Device: $($method.AdditionalProperties['displayName']), App Version: $($method.AdditionalProperties['phoneAppVersion']), Tag: $($method.AdditionalProperties['deviceTag']))"
                                }
                                "#microsoft.graph.fido2AuthenticationMethod" {
                                    "FIDO2 (Device: $($method.AdditionalProperties['displayName']), Created: $($method.AdditionalProperties['createdDateTime']), AAGUID: $($method.AdditionalProperties['aaGuid']))"
                                }
                                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                                    "Windows Hello (Device: $($method.AdditionalProperties['displayName']), Created: $($method.AdditionalProperties['createdDateTime']), Key Strength: $($method.AdditionalProperties['keyStrength']))"
                                }
                                "#microsoft.graph.emailAuthenticationMethod" {
                                    "Email (Address: $($method.AdditionalProperties['emailAddress']))"
                                }
                                "#microsoft.graph.softwareOathAuthenticationMethod" {
                                    "Software OATH"
                                }
                                default {
                                    "Unknown Method (Type: $odataType)"
                                }
                            }
                            $authMethodsList += "$($details)".replace(",", " ")
                        }
                        $authMethodsString = $authMethodsList -join ";"
                        $output = [PSCustomObject]@{
                            Name         = $user.DisplayName
                            Email        = $user.UserPrincipalName
                            AuthMethods  = $authMethodsString
                        }
                        return $output
                    }
                    catch {
                        writeLog "Failed to process account: $($user.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                    }
                }
            }
            catch {
                writeLog "Failed to retrieve matching accounts for $($_.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
            }
        } else {
            writeLog "Failed to get auth methods for $($_.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
        }
        continue
    }

    $authMethodsList = @()
    foreach ($method in $authmethods) {
        $odataType = $method.AdditionalProperties['@odata.type']
        $details = switch ($odataType) {
            "#microsoft.graph.passwordAuthenticationMethod" {
                "Password (Created: $($method.AdditionalProperties['createdDateTime']))"
            }
            "#microsoft.graph.phoneAuthenticationMethod" {
                "Phone (Number: $($method.AdditionalProperties['phoneNumber']), Type: $($method.AdditionalProperties['phoneType']), SMS Sign-In: $($method.AdditionalProperties['smsSignInState']))"
            }
            "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                "Microsoft Authenticator (Device: $($method.AdditionalProperties['displayName']), App Version: $($method.AdditionalProperties['phoneAppVersion']), Tag: $($method.AdditionalProperties['deviceTag']))"
            }
            "#microsoft.graph.fido2AuthenticationMethod" {
                "FIDO2 (Device: $($method.AdditionalProperties['displayName']), Created: $($method.AdditionalProperties['createdDateTime']), AAGUID: $($method.AdditionalProperties['aaGuid']))"
            }
            "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                "Windows Hello (Device: $($method.AdditionalProperties['displayName']), Created: $($method.AdditionalProperties['createdDateTime']), Key Strength: $($method.AdditionalProperties['keyStrength']))"
            }
            "#microsoft.graph.emailAuthenticationMethod" {
                "Email (Address: $($method.AdditionalProperties['emailAddress']))"
            }
            "#microsoft.graph.softwareOathAuthenticationMethod" {
                "Software OATH"
            }
            default {
                "Unknown Method (Type: $odataType)"
            }
        }
        $authMethodsList += "$($details)".replace(",", " ")
    }

    $authMethodsString = $authMethodsList -join ";"
    $output = [PSCustomObject]@{
        Name         = $_.DisplayName
        Email        = $_.UserPrincipalName
        AuthMethods  = $authMethodsString
    }
    return $output  # Explicitly return the custom object
}  -ThrottleLimit 10

# Check if $data is null before exporting
if ($null -ne $data) {
    $data | ForEach-Object { Write-Host $_ }
    $data | Export-Csv -Path $outpath -NoTypeInformation
} else {
    writeLog "No data to export. The script did not process any users." "warning"
}

writeLog "Completed in: $(New-TimeSpan -start $startTime -end (get-date))" "success"


