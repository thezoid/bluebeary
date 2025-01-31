#export
$exportpath = "c:\temp\exchangeContactExport.csv"
Import-Module Microsoft.Graph.Identity.DirectoryManagement
write-host "please sign in to the source tenant"
Connect-MgGraph -Scopes "User.Read", "Contacts.Read"
mkdir -p "c:\temp"
Get-MgContact  | export-csv $exportpath
read-host "finished exporting contacts, press any key to continue"

#import
Import-Module Microsoft.Graph.Identity.DirectoryManagement
write-host "please sign in to the destination tenant"
Connect-MgGraph -Scopes "User.Read", "Contacts.Read"
$importpath = "c:\temp\exchangeContactExport.csv"
Import-Csv $importpath | ForEach-Object {
     $contact = New-MgContact -GivenName $_.GivenName -Surname $_.Surname -Mail $_.EmailAddress #https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.identity.directorymanagement/new-mgcontact?view=graph-powershell-1.0
     $contact | Add-MgContact
}