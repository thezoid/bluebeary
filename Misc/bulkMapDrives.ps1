# Update to map to your locations
$drives = @{
     "X"="\\10.0.0.100\Backups"
     "Y"="\\10.0.0.100\Projects"
     "Z"="\\10.0.0.100\Home"
 }

 $cred = get-credential
  foreach ($key in $drives.Keys) {
     if (Get-PSDrive -Name $key -ErrorAction SilentlyContinue) {
         Write-Host "Found $($key) -> $($drives[$key]) already mounted"
         net use /d "$($key):"
     }
     Write-Host "Attempting to mount $($key) -> $($drives[$key])"
     try {
         New-PSDrive -Name $key -Root $drives[$key] -PSProvider FileSystem -Scope Global -Credential $cred -Persist -ErrorAction Stop
     } catch {
         Write-Error "Failed to mount $($key) -> $($drives[$key]): $_"
     }
 }