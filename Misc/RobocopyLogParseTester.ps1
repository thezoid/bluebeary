$linesToProcess = @()
$logPath = "robocopy\log\path"
$errorLineRegex = ".ERROR 123."
$maxPathAllowed = 256
Get-Content  $logPath | ?{$_ -match $errorLineRegex}|%{
     $filepath = "\\" + ($_.split("\")[2..($_.split("\").Count-1)] -join "\")
     write-host "Adding new line to processes:`n`t$filepath"
     $linesToProcess+=$filepath
}

foreach ($line in $linesToProcess){
     $sub = $line.Substring($maxPathAllowed)
     write-host "Path left after max length reached:`n`t$sub"
     if($sub -contains "\"){
          $split = $sub.Split("\")
          if($split.Count -gt 1){
               $split = $split[1..$split.Count-1]
               $split -join "\" | Out-File "c:\temp\badPaths.csv" -Append
          }
     }
}