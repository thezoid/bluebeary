param(
     [Parameter(Mandatory = $true)][string]$vaultName,
     [Parameter(Mandatory = $true)][string]$rgName,
     [Parameter(Mandatory = $false)][boolean]$createPolicy = $true,
     [Parameter(Mandatory = $false)][boolean]$unprotect = $true
)

import-module az

#vars

#funcs

#main
Write-host "Registering recovery services provider"
Register-AzResourceProvider -ProviderNamespace "Microsoft.RecoveryServices"

# set arsv context
Write-Host "Setting context to target vault"
$targetVault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rgName 
$targetVault | Set-AzRecoveryServicesVaultContext

if($createPolicy){
     if(Get-AzRecoveryServicesBackupProtectionPolicy -Name "Standard" -VaultId $targetVault.ID){
          Write-host "'Standard' already exists! Skipping policy creation"
     }else{
          Write-Host "Creating new 'Standard' Policy"
          $startDate = (Get-Date -Date "$((Get-Date -Format "yyyy-MM-dd")) 01:00:00").AddDays(1)
          $startDate = $startDate.ToUniversalTime()
          $schPol = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM"
          $schPol.ScheduleRunTimes[0] = $startDate
          $retPol = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM"
          $retPol.DailySchedule.DurationCountInDays = 30
          $retPol.WeeklySchedule.DaysOfTheWeek = ("Saturday")
          $retPol.WeeklySchedule.DurationCountInWeeks = 52
          $retPol.IsMonthlyScheduleEnabled = $false
          $retPol.IsYearlyScheduleEnabled = $false
          $retPol.IsDailyScheduleEnabled = $true
          New-AzRecoveryServicesBackupProtectionPolicy -Name "Standard" -WorkloadType "AzureVM" -RetentionPolicy $retPol -SchedulePolicy $schPol -VaultId $targetVault.ID
     }
}

$vms = Get-AzVM
foreach ($vm in $vms) {
     Write-host "`n------------`nEnabling policy for $($vm.Name)"
     if($targetVault.Location -ne $vm.Location){
          write-host "Vault [$($targetVault.Name)] and VM[$($vm.Name)] are in different regions - Skipping" -ForegroundColor Yellow
          continue
     }
     # if((Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type 'AzureVM').BackedUp){
     #      Write-Host "VM [$($vm.Name)] already protected - Skipping"
     #      Continue
     # }
     #check if the VM is already protected in another vault
     if($unprotect -and (Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type 'AzureVM').BackedUp){
          Write-host "VM[$($vm.Name)] already protected!"
          #get the current vault id for the backup
          $otherVaultID = (Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type 'AzureVM').VaultId
          if($otherVaultID -eq $targetVault.ID){
               Write-Host "Protection is already provided by target vault!" -ForegroundColor Green
               continue
          }else{
               Write-Host "Protection is from another vault - removing" -ForegroundColor Yellow
          }
          #get the current vm backup item
          $bkpItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -Name $vm.Name-VaultId $otherVaultID
          #disable soft delete to force delete recovery points
          $softDeleteDisabled = $false
          if((get-AzRecoveryServicesVaultProperty -VaultId $otherVaultID).SoftDeleteFeatureState -eq "Enabled"){
               Write-Host "Warning - disabling soft delete temporarily" -ForegroundColor Yellow
               Set-AzRecoveryServicesVaultProperty -VaultId $otherVaultID -SoftDeleteFeatureState Disable
               $softDeleteDisabled = $true
          }
          #disable the vm backup item and delete recovery points
          Disable-AzRecoveryServicesBackupProtection -Item $bkpItem -VaultId $targetVault.ID -RemoveRecoveryPoints -Force
          #reenable soft delete
          if($softDeleteDisabled){
               Write-Host "Renabling soft delete" -ForegroundColor Green
               Set-AzRecoveryServicesVaultProperty -VaultId $otherVaultID -SoftDeleteFeatureState Enable
          }
          Write-host "Adding VM[$($vm.Name)] backup protection"
          #get the policy to enable on the vm
          $pol = Get-AzRecoveryServicesBackupProtectionPolicy -Name "Standard" -VaultId $targetVault.ID
          #enable the policy on the vm
          Enable-AzRecoveryServicesBackupProtection -Policy $pol -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -VaultId $targetVault.ID
     }elseif(-not((Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type 'AzureVM').BackedUp)){
          Write-Host "VM[$($vm.Name)] is not currently protected, adding protection"
          #get the policy to enable on the vm
          $pol = Get-AzRecoveryServicesBackupProtectionPolicy -Name "Standard" -VaultId $targetVault.ID
          #enable the policy on the vm
          Enable-AzRecoveryServicesBackupProtection -Policy $pol -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -VaultId $targetVault.ID
     }else{
          Write-Host "VM[$($vm.Name)] is already protected - run with '-unprotected `$true' to overwrite"
     }
}

