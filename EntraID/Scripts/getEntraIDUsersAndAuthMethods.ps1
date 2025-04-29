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

#force tls 1.2
[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$erroractionpreference = "stop"
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
"Name,Email,Enabled,Auth Methods" | out-file $outpath
$users = Get-MgUser -All
$count = 0
$startTime = get-date
foreach ($user in $users) {
    $count++
    writeLog "[$($count)/$($users.count)] checking $($user.UserPrincipalName)" "info"
    try {
        $authmethods = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName
    }
    catch {
        writeLog "failed to get auth methods from $($user.UserPrincipalName)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
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
    $enabledState = if ($authmethods.Count -gt 0) { "True" } else { "False" }

    "$($user.DisplayName),$($user.UserPrincipalName),$enabledState,$authMethodsString" | out-file $outpath -Append
}
writeLog "Completed in: $(New-TimeSpan -start $startTime -end (get-date))" "success"


