
param(
    [Parameter(Mandatory = $True)][string]$workspaceID,
    [Parameter(Mandatory = $True)][string]$workspaceKey,
    [Parameter(Mandatory = $False)][boolean]$ReInstall = $True
)

import-module az

#LA extension constants
$MMAExtensionMap = @{ "Windows" = "MicrosoftMonitoringAgent"; "Linux" = "OmsAgentForLinux" }
$MMAExtensionVersionMap = @{ "Windows" = "1.0"; "Linux" = "1.6" }
$MMAExtensionPublisher = "Microsoft.EnterpriseCloud.Monitoring"
$MMAExtensionName = "MMAExtension"
$PublicSettings = @{"workspaceId" = $workspaceID; "stopOnMultipleConnections" = "false" }
$ProtectedSettings = @{"workspaceKey" = $workspaceKey }

# Dependency Agent Extension constants
$DAExtensionMap = @{ "Windows" = "DependencyAgentWindows"; "Linux" = "DependencyAgentLinux" }
$DAExtensionVersionMap = @{ "Windows" = "9.5"; "Linux" = "9.5" }
$DAExtensionPublisher = "Microsoft.Azure.Monitoring.DependencyAgent"
$DAExtensionName = "DAExtension"

# funcs
function Get-VMExtension {
    <#
    .SYNOPSIS
    Return the VM extension of specified ExtensionType
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)][string]$VMName,
        [Parameter(mandatory = $true)][string]$vmResourceGroupName,
        [Parameter(mandatory = $true)][string]$ExtensionType
    )

    $vm = Get-AzVM -Name $VMName -ResourceGroupName $vmResourceGroupName -DisplayHint Expand
    $extensions = $vm.Extensions

    foreach ($extension in $extensions) {
        if ($ExtensionType -eq $extension.VirtualMachineExtensionType) {
            Write-Verbose("$VMName : Extension: $ExtensionType found on VM")
            $extension
            return
        }
    }
    Write-Verbose("$VMName : Extension: $ExtensionType not found on VM")
}

function Install-VMExtension {
    <#
    .SYNOPSIS
    Install VM Extension, handling if already installed
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)][string]$VMName,
        [Parameter(mandatory = $true)][string]$VMLocation,
        [Parameter(mandatory = $true)][string]$VMResourceGroupName,
        [Parameter(mandatory = $true)][string]$ExtensionType,
        [Parameter(mandatory = $true)][string]$ExtensionName,
        [Parameter(mandatory = $true)][string]$ExtensionPublisher,
        [Parameter(mandatory = $true)][string]$ExtensionVersion,
        [Parameter(mandatory = $false)][hashtable]$PublicSettings,
        [Parameter(mandatory = $false)][hashtable]$ProtectedSettings,
        [Parameter(mandatory = $false)][boolean]$ReInstall
    )
    # Use supplied name unless already deployed, use same name
    $extensionName = $ExtensionName

    $extension = Get-VMExtension -VMName $VMName -VMResourceGroup $VMResourceGroupName -ExtensionType $ExtensionType
    if ($extension) {
        $extensionName = $extension.Name

        # of has Settings - it is LogAnalytics extension
        if ($extension.Settings) {
            if ($extension.Settings.ToString().Contains($PublicSettings.workspaceId)) {
                $message = "$VMName : Extension $ExtensionType already configured for this workspace. Provisioning State: " + $extension.ProvisioningState + " " + $extension.Settings
                Write-Output($message)
            }
            else {
                if ($ReInstall -ne $true) {
                    $message = "$VMName : Extension $ExtensionType already configured for a different workspace. Run with -ReInstall to move to new workspace. Provisioning State: " + $extension.ProvisioningState + " " + $extension.Settings
                    Write-Warning($message)
                }
            }
        }
        else {
            $message = "$VMName : $ExtensionType extension with name " + $extension.Name + " already installed. Provisioning State: " + $extension.ProvisioningState + " " + $extension.Settings
            Write-Output($message)
        }
    }

    if ($PSCmdlet.ShouldProcess($VMName, "install extension $ExtensionType") -and ($ReInstall -eq $true -or !$extension)) {

        $parameters = @{
            ResourceGroupName= $VMResourceGroupName
            VMName= $VMName
            Location= $VMLocation
            Publisher= $ExtensionPublisher
            ExtensionType= $ExtensionType
            ExtensionName= $extensionName
            TypeHandlerVersion = $ExtensionVersion
        }

        if ($PublicSettings -and $ProtectedSettings) {
            $parameters.Add("Settings", $PublicSettings)
            $parameters.Add("ProtectedSettings", $ProtectedSettings)
        }

        if ($ExtensionType -eq "OmsAgentForLinux") {
            Write-Output("$VMName : ExtensionType: $ExtensionType does not support updating workspace. Uninstalling and Re-Installing")
            $removeResult = Remove-AzVMExtension -ResourceGroupName $VMResourceGroupName -VMName $VMName -Name $extensionName -Force

            if ($removeResult -and $removeResult.IsSuccessStatusCode) {
                $message = "$VMName : Successfully removed $ExtensionType"
                Write-Output($message)
            }
            else {
                $message = "$VMName : Failed to remove $ExtensionType (for $ExtensionType need to remove and re-install if changing workspace with -ReInstall)"
                Write-Warning($message)
            }
        }

        Write-Output("$VMName : Deploying $ExtensionType with name $extensionName")
        $result = Set-AzVMExtension @parameters

        if ($result -and $result.IsSuccessStatusCode) {
            $message = "$VMName : Successfully deployed $ExtensionType"
            Write-Output($message)
        }
        else {
            $message = "$VMName : Failed to deploy $ExtensionType"
            Write-Warning($message)
        }
    }
}

#main
Register-AzResourceProvider -ProviderNamespace Microsoft.AlertsManagement
$vms = Get-AzVM
foreach ($vm in $vms) {
    $osType = $vm.StorageProfile.OsDisk.OsType
    $vmName = $vm.Name
    $vmLocation = $vm.Location
    $vmResourceGroupName = $vm.ResourceGroupName

    $mmaExt = $MMAExtensionMap.($osType.ToString())
    if (! $mmaExt) {
        Write-Warning("$vmName : has an unsupported OS: $osType")
        continue
    }
    $mmaExtVersion = $MMAExtensionVersionMap.($osType.ToString())
    $daExt = $DAExtensionMap.($osType.ToString())
    $daExtVersion = $DAExtensionVersionMap.($osType.ToString())
    
    if ("PowerState/running" -ne $(Get-AzVM -status -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name).Statuses[1].Code) {
        $message = "$vmName : Not running - Skipping"
        Write-Output($message)
        continue
    }
    
    Install-VMExtension `
        -VMName $vmName `
        -VMLocation $vmLocation `
        -VMResourceGroupName $vmResourceGroupName `
        -ExtensionType $mmaExt `
        -ExtensionName $mmaExtensionName `
        -ExtensionPublisher $MMAExtensionPublisher `
        -ExtensionVersion $mmaExtVersion `
        -PublicSettings $PublicSettings `
        -ProtectedSettings $ProtectedSettings `
        -ReInstall $ReInstall

    Install-VMExtension `
        -VMName $vmName `
        -VMLocation $vmLocation `
        -VMResourceGroupName $vmResourceGroupName `
        -ExtensionType $daExt `
        -ExtensionName $daExtensionName `
        -ExtensionPublisher $DAExtensionPublisher `
        -ExtensionVersion $daExtVersion `
        -ReInstall $ReInstall `
}