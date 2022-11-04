#this script was made to read a massive file server transfer's log for "filename too long" robocopy errors
#then it deals with that by smartly truncating each segment of the path

#region vars
$shortenFolders = $true
$lengthBuffer = 5 #how many characters to include on both sides of the truncation
#endregion

#region parse robocopy log files
$linesToProcess = @()
$logPath = "robocopy\log\path"
$errorLineRegex = ".ERROR 123."
$maxPathAllowed = 256
Get-Content  $logPath | ?{$_ -match $errorLineRegex}|%{
     $filepath = "\\"+$_.split("\\")[1]
     write-host "Adding new line to processes:`n`t$filepath"
     $linesToProcess+=$filepath
}
#endregion



foreach($line in $linesToProcess){
     $split = $line.Split("\")
     #region build new filename
     #$currentName = "c:\some\long\path\this is a really long name for a file\this is a really long name for a file.txt" #some file to shorten
     Write-Host "Attempting to process filename"
     
     $fileName = $split[$split.Count-1] #get the filename from the path
     if($fileName.Length -ge $lengthBuffer*2){
          $indexOfDot = $fileName.IndexOf(".") #find out where the . is # assumption, there is only a dot for the extension
          $extension = $fileName.Substring($indexOfDot+1) #get the extension after the dot
          $newName = $fileName.Substring(0,$lengthBuffer) + "~"+$fileName.Substring(($indexOfDot-$lengthBuffer),$lengthBuffer)+"."+$extension #build the new truncated name
          $newName = $newName.replace(" ","")
          Write-Host "Processed filename:`n`t$newName" -ForegroundColor Green
     }else{
          Write-host "Skipping: the length of the file name is not longer than $($lengthBuffer*2):`n`t$fileName"
          $newName = $fileName.Replace(" ","")
     }

     #shorten path
     if($shortenFolders){
          Write-Host "Attempting to truncate the file path:`n`t$line"
          $newPathParts = @()
          for ($i = 0; $i -lt $split.Count; $i++){
               if($i -eq 0 -or $i -eq $split.Count-1){continue}
               $pathItem = $split[$i]
               if ($pathItem.Length -le $lengthBuffer*2) {
                    Write-Host "Skipping: Path part too short"
                    $newPathParts += ($pathItem).Replace(" ","")
               }else{
                    Write-host "Attempting to shorten path part:`n`t$pathItem"
                    $newPathParts+= ($pathItem.Substring(0,$lengthBuffer) + "~"+$pathItem.Substring(($pathItem.Length - $lengthBuffer),$lengthBuffer)).Replace(" ","")
               }
          }
          $newPath = $newPathParts -join "\"
     }else{
          $newPath = ($split[0..$split.Count-2] -join "\").Replace(" ","")
     }
     
     write-host "The new truncated path is:`n`t$newPath\$newName"
     #endregion

     #region build destination path
     $destination = "\\remoteServer\rootLocation" #!!! change to correct remote server root copy target
     $copyTarget = "$destination\$newPath\$newName"
     #endregion

     #region copy to new destination
     
     Write-host "Attempting to copy:`n`tFrom: $line`n`tTo:$copyTarget"
     if ($copyTarget.Length -lt $maxPathAllowed) {
          Copy-Item -Path $line -Destination $copyTarget          
     }else{
          Write-Host "Truncated path still too long:`n`tNew Path: $copyTarget`n`tLength: $($copyTarget.Length)" -ForegroundColor Red
     }

     #endregion
}