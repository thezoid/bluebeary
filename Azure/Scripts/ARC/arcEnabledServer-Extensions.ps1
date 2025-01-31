import-module Az
import-module Az.ConnectedMachine
$ErrorActionPreference = "stop"
$jobCount = 0
$jobLimit = 32

function writeLog([string]$message, [string]$status) {
    if (-not $status -or $status -eq "") {
        $status = "info"
    }
    switch ($status.ToLower()) {
        "info" { 
            write-host "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Blue
            try { "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
        }
        "warning" { 
            write-host "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Yellow
            try { "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
        }
        "error" { 
            write-host "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Red
            try { "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
        }
    }
}

writeLog "attempting to get az connected machines..." "info"
$targets = Get-AzConnectedMachine
writeLog "found $($targets.count) connected machines" "info"
$count = 0
foreach ($target in $targets) {
    $count++
    writeLog "[$($count)/$($targets.count)] processing $($target.name)" "info"
    switch ($target.OSType.tolower()) {
        "windows" {
            $installAMA = $true
            writeLog "$($target.name) is a Windows device!" "info"
            try {
                writeLog "attempting to get cmes on $($target.name)"
                $cmes = Get-AzConnectedMachineExtension -ResourceGroupName $target.ResourceGroupName -MachineName $target.Name
            }
            catch {
                writeLog "Failed to get CME on $($target.name)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                continue
            }
            writeLog "Found $($cmes.count) extensions" "info"
            foreach ($cme in $cmes) {
                if ($cmes.Name.tolower() -eq "azuremonitorwindowsagent") {
                    writeLog "ama already found on $($target.name), disabling install flag" "info"
                    $installAMA = $false
                }
            }
            if ($installAMA) {
                try {
                    if ($jobCount -ge $jobLimit) {
                        writeLog "[jobCount: $($jobCount)] [$($_target.name)] hit job cap, waiting..." "info"
                        Get-Job -State Running | Wait-Job -Any
                        $jobCount = (Get-Job -State Running).Count
                    }

                    Start-Job -ScriptBlock {
                        param($_target)
                        function writeLog([string]$message, [string]$status) {
                            if (-not $status -or $status -eq "") {
                                $status = "info"
                            }
                            switch ($status.ToLower()) {
                                "info" { 
                                    write-host "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Blue
                                    try { "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
                                }
                                "warning" { 
                                    write-host "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Yellow
                                    try { "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
                                }
                                "error" { 
                                    write-host "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Red
                                    try { "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
                                }
                            }
                        }
                        writeLog "attempting to install AMA on on $($_target.name)..." "info"
                        New-AzConnectedMachineExtension -MachineName $_target.name -ResourceGroupName $_target.ResourceGroupName -Location $_target.location -ExtensionType "azuremonitorwindowsagent" -Publisher Microsoft.Azure.Monitor -Name AzureMonitorWindowsAgent
                        writeLog "installed AMA on on $($_target.name)" "info"
                    } -ArgumentList $target
                    $jobCount++
                    
                }
                catch {
                    writeLog "Failed to install AMA on $($target.name)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                }
                # try {
                #     writeLog "attempting to add $($target.Name) to windows dcr..." "info"
                #     $dcr = Get-AzDataCollectionRule -ResourceGroupName "RG-EUS2-Prod-Monitoring" -RuleName "law-prod-monitoring-linuxDCR"
                #     $dcr | New-AzDataCollectionRuleAssociation -TargetResourceId $target.VMId -AssociationName "dcrAssocInput"
                #     writeLog "added $($target.Name) to windows dcr" "info"
                # }
                # catch {
                #     writeLog "Failed to add to windows dcr on $($target.name)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                # }
            }           
        }
        "linux" {
            $installAMA = $true
            writeLog "$($target.name) is a Linux device!" "info"
            $cmes = Get-AzConnectedMachineExtension -ResourceGroupName $target.ResourceGroupName -MachineName $target.Name
            writeLog "Found $($cmes.count) extensions" "info"
            foreach ($cme in $cmes) {
                if ($cmes.Name.tolower() -eq "azuremonitorlinuxagent") {
                    writeLog "ama already found on $($target.name), disabling install flag" "info"
                    $installAMA = $false
                }
            }
            if ($installAMA) {
                try {

                    if ($jobCount -ge $jobLimit) {
                        writeLog "[jobCount: $($jobCount)] [$($_target.name)] hit job cap, waiting..." "info"
                        Get-Job -State Running | Wait-Job -Any
                        $jobCount = (Get-Job -State Running).Count
                    }

                    Start-Job -ScriptBlock {
                        param($_target)
                        function writeLog([string]$message, [string]$status) {
                            if (-not $status -or $status -eq "") {
                                $status = "info"
                            }
                            switch ($status.ToLower()) {
                                "info" { 
                                    write-host "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Blue
                                    try { "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
                                }
                                "warning" { 
                                    write-host "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Yellow
                                    try { "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
                                }
                                "error" { 
                                    write-host "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Red
                                    try { "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\logs\$(get-date -Format "yyyyMMMdd")-ArcExtensionAutomation.log" -Append }catch {} 
                                }
                            }
                        }
                        writeLog "attempting to install AMA on on $($_target.name)..." "info"
                        New-AzConnectedMachineExtension -MachineName $_target.name -ResourceGroupName $_target.ResourceGroupName -Location $_target.location -ExtensionType "azuremonitorlinuxagent" -Publisher Microsoft.Azure.Monitor -Name AzureMonitorLinuxAgent
                        writeLog "installed AMA on on $($_target.name)" "info"
                    } -ArgumentList $target
                    $jobCount++
                }
                catch {
                    writeLog "Failed to install ama extension on $($target.name)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                }
                # try {
                #     writeLog "attempting to add $($target.Name) to linux dcr..." "info"
                #     $dcr = Get-AzDataCollectionRule -ResourceGroupName "RG-EUS2-Prod-Monitoring" -RuleName "law-prod-monitoring-linuxDCR"
                #     $dcr | New-AzDataCollectionRuleAssociation -TargetResourceId $target.VMId -AssociationName "dcrAssocInput"
                #     writeLog "added $($target.Name) to linux dcr" "info"
                # }
                # catch {
                #     writeLog "Failed to add to linux dcr on $($target.name)`n----- Error Start -----`n$_`n----- Error End -----`n" "error"
                # }
            }
        }
        default{
            writeLog "$($target.name) had an unaccounted for OS [$($target.OSType.tolower())]" "warning"
        }
    }
}


# Wait for all jobs to complete
Get-Job | Wait-Job

# Retrieve job results and remove jobs
Get-Job | Receive-Job | Remove-Job