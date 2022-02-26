function GetRandomCharacters($length, $characters) {
     $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
     $private:ofs = ""
     return [String]$characters[$random]
}

function ScrambleString([string]$inputString) {     
     $characterArray = $inputString.ToCharArray()   
     $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
     $outputString = -join $scrambledStringArray
     return $outputString 
}

function GeneratePassword($length, $characters) {
     do {
          $randomPassword = GetrandomCharacters -length 15 -characters $characterList
          $createdPassword = ScrambleString $randomPassword
     } until ($createdPassword -match '\d' -and
          $createdPassword -cmatch '[A-Z]' -and
          $createdPassword -cmatch '[a-z]' -and
          $createdPassword -cmatch '[!@#$%^&*]')

     return $createdPassword
}

if(-not $PSVersionTable.PSVersion.Major -eq 7){
     Write-Host "This script requires PowerShell 7.x.x"
     Write-Host "You can download it from: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.1#installing-the-msi-package"
     return
}

$specialCharacterList = '!@#$%^&*'.ToCharArray()
$characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $specialCharacterList
$username = ""
$sentinel = "exit"
while ($username.ToLower() -ne $sentinel.ToLower()) {
     $username = Read-Host "Please provide an Active Directory Username"
     if($username.ToLower() -eq $sentinel.ToLower()){
          write-host "Application will close now - goodbye"
          break
     }
     if ((get-aduser "$username")) {
          $randomConfirm = Read-Host "Do you want to generate a random password? Y/n"
          if ($randomConfirm.ToLower() -eq "y") {
               $confirm = Read-Host "Are you sure you want to generate a random pasword for $($username)? y/N"
               if ($confirm.ToLower() -eq "y") {
                    $newPass = GeneratePassword -length 16 -characters $characterList
                    Set-ADAccountPassword -Identity $username -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force)
                    Write-host "The password has been changed to $newPass"
               }
               else {
                    write-host "Password was not changed"
               }
          }
          else {
               $newPass = Read-Host "Please provide the new password"
               Set-ADAccountPassword -Identity $username -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force)
               Write-host "The password has been changed to $newPass"
          }
     }
     else {
          Write-Host "Could not find user - try again"
     }
     Write-Host "`n`n==================================================`n`n"
}

