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
          $randomPassword = GetrandomCharacters -length $length -characters $characterList
          $createdPassword = ScrambleString $randomPassword
     } until ($createdPassword -match '\d' -and
          $createdPassword -cmatch '[A-Z]' -and
          $createdPassword -cmatch '[a-z]' -and
          $createdPassword -cmatch '[!@#$%^&*]' )

     return $createdPassword
}

if(-not $PSVersionTable.PSVersion.Major -eq 7){
     Write-Host "This script requires PowerShell 7.x.x"
     Write-Host "You can download it from: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.1#installing-the-msi-package"
     return
}

$specialCharacterList = '!@#$%^&*'.ToCharArray()
$characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $specialCharacterList
$numtocreate = read-host "how many passwords to generate"
$passLength = read-host "how long should passwords be"
for ($i = 0; $i -lt $numtocreate; $i++) {
     $pass = GeneratePassword -length $passLength -characters $characterList
     write-host "$pass"
}