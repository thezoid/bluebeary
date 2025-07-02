param(
     [Parameter(Mandatory = $true)]
     [string]$resourceGroupName,
     [Parameter(Mandatory = $true)]
     [string]$storageAccountName,
     [Parameter(Mandatory = $true)]
     [string]$shareName,
     [int]$daysThreshold = 90,
     [switch]$whatIf
)

function writeLog([string]$message, [string]$status = "info") {
     $timestamp = "$(Get-Date -Format "yyyyMMMdd@hh:mm:ss")"
     switch ($status.ToLower()) {
          "info" { $color = "Blue"; $prefix = "*" }
          "success" { $color = "Green"; $prefix = "^" }
          "warning" { $color = "Yellow"; $prefix = "!" }
          "error" { $color = "Red"; $prefix = "!!!" }
          default { $color = "Blue"; $prefix = "*" }
     }

     $outputMessage = "$prefix[$timestamp] $message"
     Write-Host $outputMessage -ForegroundColor $color

     if (-not $whatIf) {
          if (-not (Test-Path "C:\temp\logs")) {
               New-Item -Path "C:\temp\logs" -ItemType Directory | Out-Null
          }
          $logFile = "C:\temp\logs\$(Get-Date -Format \"yyyyMMMdd\")-AzureFileCleanup.log"
          $maxRetries = 5
          $retryDelayMs = 200
          for ($i = 0; $i -lt $maxRetries; $i++) {
               try {
                    $outputMessage | Add-Content -Path $logFile -Force
                    break
               }
               catch {
                    if ($i -eq ($maxRetries - 1)) {
                         Write-Host "Failed to write to log file after $maxRetries attempts: $_" -ForegroundColor Red
                    }
                    else {
                         Start-Sleep -Milliseconds $retryDelayMs
                    }
               }
          }
     }
     else {
          Write-Host "WhatIf: skipping log file write" -ForegroundColor Yellow
     }
}

function Get-AllFileItems($shareName, $ctx, $path) {
     $allItems = @()
     try {
          $items = Get-AzStorageFile -ShareName $shareName -Path $path -Context $ctx -ErrorAction Stop
     } catch {
          if ($_.Exception.Message -like "*ResourceNotFound*") {
               writeLog "Path '$path' not found in share '$shareName', skipping." "warning"
               return $allItems
          } else {
               throw
          }
     }
     foreach ($item in $items) {
          if ($item.CloudFileDirectory -ne $null) {
               $subDirName = if ($path) { Join-Path -Path $path -ChildPath $item.CloudFileDirectory.Name } else { $item.CloudFileDirectory.Name }
               $allItems += $item
               $allItems += Get-AllFileItems -shareName $shareName -ctx $ctx -path $subDirName
          }
          elseif ($item.CloudFile -ne $null) {
               $allItems += $item
          }
     }
     return $allItems
}

# Ensure Az module is available
if (-not $whatIf) {
     if (-not (Get-Module -ListAvailable -Name Az)) {
          Write-Host "Az module not found; installing..." -ForegroundColor Yellow
          Install-Module -Name Az -Scope CurrentUser -Force -ErrorAction Stop
     }
     Import-Module Az -ErrorAction Stop
}
else {
     Write-Host "WhatIf: skipping Az module installation/import" -ForegroundColor Yellow
}

try {
     writeLog "Starting cleanup for share '$shareName' in storage account '$storageAccountName' (resource group '$resourceGroupName')" "info"

     writeLog "Connecting to Azure account" "info"
     Connect-AzAccount | Out-Null
     writeLog "Connected to Azure account" "success"

     writeLog "Retrieving storage account context" "info"
     $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction Stop
     $ctx = $storageAccount.Context
     writeLog "Storage account context retrieved" "success"

     writeLog "Retrieving directories in share '$shareName'" "info"
     $items = Get-AzStorageFile -ShareName $shareName -Path "" -Context $ctx -ErrorAction Stop
     $directories = $items | Where-Object { $_.CloudFileDirectory -ne $null }
     writeLog "Found $($directories.Count) directories" "info"

     $cutoffDate = (Get-Date).AddDays(-$daysThreshold)
     writeLog "Cutoff date: $cutoffDate" "info"

     $deletedCount = 0
     $skippedCount = 0
     $emptyCount = 0
     $notFoundCount = 0

     foreach ($dir in $directories) {
          $dirName = $dir.CloudFileDirectory.Name

          # Recursively get all files and subdirectories under this directory
          $allItems = Get-AllFileItems -shareName $shareName -ctx $ctx -path $dirName

          # Filter to only files for last modified check
          $allFiles = $allItems | Where-Object { $_.CloudFile -ne $null }

          if ($allFiles.Count -eq 0) {
               # If directory is empty, try to use its own last modified date if available
               try {
                    $lastModified = $dir.CloudFileDirectory.Properties.LastModified.UtcDateTime
                    writeLog "Directory '$dirName' is empty. Using directory's own last modified: $lastModified" "info"
                    $emptyCount++
               } catch {
                    $lastModified = $null
                    writeLog "Directory '$dirName' is empty and has no last modified property. Skipping." "warning"
                    $notFoundCount++
               }
          }
          else {
               $lastModified = ($allFiles | ForEach-Object {
                    try {
                         $_.CloudFile.ICloudBlob.Properties.LastModified.UtcDateTime
                    } catch {
                         $null
                    }
               } | Sort-Object -Descending | Select-Object -First 1)
               writeLog "Directory '$dirName' has files. Latest file last modified: $lastModified" "info"
          }

          if (-not $lastModified) {
               writeLog "Directory '$dirName' has no valid last modified date. Skipping." "warning"
               $skippedCount++
               continue
          }

          if ($lastModified -lt $cutoffDate) {
               writeLog "Directory '$dirName' is older than cutoff ($lastModified < $cutoffDate). Would be deleted." "success"
               $deletedCount++
               if (-not $whatIf) {
                    try {
                         Remove-AzStorageFileContent -ShareName $shareName -Context $ctx -Path $dirName -Force -Recurse -ErrorAction Stop
                         writeLog "Deleted directory '$dirName' successfully" "success"
                    }
                    catch {
                         writeLog "Error deleting '$dirName': $_" "error"
                    }
               }
               else {
                    writeLog "WhatIf: skipping deletion of '$dirName'" "info"
               }
          }
          else {
               writeLog "Directory '$dirName' is newer than cutoff ($lastModified >= $cutoffDate). Skipping." "info"
               $skippedCount++
          }
     }

     writeLog "Cleanup process completed" "success"
     writeLog "Summary: $deletedCount directories would be deleted, $skippedCount skipped, $emptyCount empty, $notFoundCount not found or no last modified." "info"
}
catch {
     writeLog "Script encountered an error: $_" "error"
     throw
}
finally {
     writeLog "Disconnecting from Azure account" "info"
     Disconnect-AzAccount | Out-Null
     writeLog "Disconnected from Azure account" "success"
}
