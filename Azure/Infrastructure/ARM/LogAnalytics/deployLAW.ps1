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

$templateFilePath = Join-Path -Path $PSScriptRoot -ChildPath "LogAnalytics.json"

Write-Host "Start log analytics workspace deployment"
Write-Host "Param object vals:`n`tlawdataRetention: $($parameters.lawdataRetention.value)`n`tlawMSFTSolutions: $($parameters.lawMSFTSolutions.value)`n`tregion: $($parameters.region.value)`n`tsystem: $($parameters.system.value)`n`tenvironment: $($parameters.environment.value)"
$paramsObj = @{
    'lawdataRetention'=$parameters.lawdataRetention.value
    'lawMSFTSolutions'=$parameters.lawMSFTSolutions.value
    'region'=$parameters.region.value
    'system'=$parameters.system.value
    'environment'=$parameters.environment.value
}

New-AzResourceGroupDeployment `
-ResourceGroupName $sharedHubResourceGroupName `
-TemplateFile $templateFilePath `
-TemplateParameterObject $paramsObj `
-ErrorAction Stop

$LAWOutputs = (Get-AzResourceGroupDeployment -ResourceGroupName $sharedHubResourceGroupName -Name "LogAnalytics").Outputs.law.value

if($runEnrollment){
    $enrollmentScriptPath =  Join-Path $parentPath "/LogAnalytics/enrollment.ps1"
    Invoke-Expression  "& `"$enrollmentScriptPath`" -workspaceID $($LAWOutputs.workspaceID.value) -workspaceKey $($LAWOutputs.primKey.value) -ErrorAction Continue"
}