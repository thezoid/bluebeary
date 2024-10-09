$SENTINEL = "exit"
while($true){
    $SteamId = read-host "provide a steamID64 (Dec)" #"76561198067545942"
    if($SteamId.ToLower() -eq $SENTINEL.ToLower()){
        break
    }
    $sID = $SteamId.ToString()
    $chars = $sID.ToCharArray()
    $bytes = New-Object byte[] $chars.Length
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $bytes[$i] = [byte]$chars[$i]
    }

    $sha = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
    $binaryData = $sha.ComputeHash($bytes)

    $arrayLength = [math]::Ceiling((4.0 / 3.0) * $binaryData.Length)
    if ($arrayLength % 4 -ne 0) {
        $arrayLength += 4 - ($arrayLength % 4)
    }
    $base64CharArray = New-Object char[] $arrayLength
    [System.Convert]::ToBase64CharArray($binaryData, 0, $binaryData.Length, $base64CharArray, 0)

    $DAYZID = [string]::Empty
    foreach ($c in $base64CharArray) {
        $DAYZID += $c
    }

    Write-Host "Steam ID:`t$SteamId"
    Write-Host "DayZ ID:`t$DAYZID"
}

