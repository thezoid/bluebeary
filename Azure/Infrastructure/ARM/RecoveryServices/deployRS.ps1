param (
    $parameterFileName,
    $runAsAccountKey,
    $runEnrollment = $true
)

Import-Module Az.Resources

$currentDirectory = if ($PSScriptRoot) { $PSScriptRoot } `
    elseif ($psise) { split-path $psise.CurrentFile.FullPath } `
    elseif ($psEditor) { split-path $psEditor.GetEditorContext().CurrentFile.Path }

Set-Location $currentDirectory

# Load global variables
$parentPath = Split-Path ((Get-Location) | Get-Item)
$helperScriptPath = Join-Path $parentPath "/Helper/ParameterHelper.ps1"

Write-Host "Loading global variables from $($helperScriptPath)"
Invoke-Expression "& `"$helperScriptPath`" $parameterFileName"

$templateFilePath = Join-Path -Path $PSScriptRoot -ChildPath "RecoveryServices.json"

Write-Host "Start log analytics workspace deployment"
Write-Host "Param object vals:`n`tregion: $($parameters.region.value)`n`tsystem: $($parameters.system.value)`n`tenvironment: $($parameters.environment.value)"
$paramsObj = @{
     'region'=$parameters.region.value
     'system'=$parameters.system.value
     'environment'=$parameters.environment.value
}

New-AzResourceGroupDeployment -ResourceGroupName $sharedHubResourceGroupName `
-TemplateFile $templateFilePath `
-TemplateParameterObject $paramsObj `
-ErrorAction Stop

$RSVOutputs = (Get-AzResourceGroupDeployment -ResourceGroupName $sharedHubResourceGroupName -Name "RecoveryServices").Outputs
Write-Host $RSVOutputs

if($runEnrollment){
     $enrollmentScriptPath =  Join-Path $parentPath "/RecoveryServices/RSEnrollment.ps1"
     Invoke-Expression  "& `"$enrollmentScriptPath`" -vaultName $($RSVOutputs.rsvName.value) -rgName $($sharedHubResourceGroupName) -ErrorAction Continue"
 }