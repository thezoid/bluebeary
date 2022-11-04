$account = "Student"
$ou = "FILL IN THE DISTINGUISHED NAME"
$group = "FILL IN SG NAME"
$amountToCreate = 350
for ($i = 1; $i -le $amountToCreate; $i++) {
     $uname = "$($Account)$($i)"
     $pass = ConvertTo-SecureString -string "Student$i" -AsPlainText -Force
     #get more flags from https://docs.microsoft.com/en-us/powershell/module/addsadministration/new-aduser?view=win10-ps
     New-ADUser -path $ou -UserPrincipalName $uname -enabled $true -PasswordNeverExpires $true 
     #get more flags from https://docs.microsoft.com/en-us/powershell/module/addsadministration/add-adgroupmember?view=win10-ps
     Add-ADGroupMember -Identity $group -Members $uname
}