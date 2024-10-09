$templatePath = "$PSScriptRoot\LogAnalytics.json"
$parameterPath = "$PSScriptRoot\LogAnalytics.parameters.json"
$targetRG = "RG-EUS2-Prod-Monitoring"

New-AzResourceGroupDeployment `
     -ResourceGroupName $targetRG `
     -TemplateFile $templatePath `
     -TemplateParameterFile $parameterPath `
     -ErrorAction Stop

$LAWOutputs = (Get-AzResourceGroupDeployment -ResourceGroupName $sharedHubResourceGroupName -Name "LogAnalytics").Outputs.law.value
write-host "LAW deployment output variables:`n----------`n$LAWOutputs`n----------`n"

