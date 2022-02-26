Install-Module AzureADPreview
Import-module AzureADPreview
write-host "Connecting to Azure AD..." -ForegroundColor Yellow
connect-azuread
$headers = "DisplayName,UserPrincipalName,LastLogon"
$report = "$headers`n"
$allAADUsers = get-azureaduser
foreach($user in $allMSOLUsers){
    write-host "$($user.DisplayName),$($user.UserPrincipalName)"
    $report+="$($user.DisplayName),$($user.UserPrincipalName),$((Get-AzureAdAuditSigninLogs -top 1 -filter "userprincipalname eq '$($user.UserPrincipalName)'" | select CreatedDateTime).CreatedDateTime)"
}