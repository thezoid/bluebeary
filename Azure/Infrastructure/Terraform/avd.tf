locals {
  current_time        = timestamp()
  expiration_duration = "4h" # Example for 4 hours. Adjust the duration as needed.
}

resource "azurerm_resource_group" "avdRG" {
  name     = var.avdRGName
  location = var.location
  tags     = var.avdTags
}

resource "azurerm_subnet" "avdSubnet" {
  name                 = var.avdSubnetName
  resource_group_name  = azurerm_resource_group.networkRG.name
  virtual_network_name = azurerm_virtual_network.sharedServicesVnet.name
  address_prefixes     = [var.avdSubnetPrefix]
}

resource "azurerm_virtual_desktop_host_pool" "avdPool" {
  name                     = var.avdPoolName
  location                 = var.location
  resource_group_name      = azurerm_resource_group.avdRG.name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = var.avdPoolMaxConcurrentSessions
  friendly_name            = var.avdPoolFriendlyName
  description              = var.avdPoolDescription
  tags                     = var.avdTags
  custom_rdp_properties    = "enablecredsspsupport:i:1;videoplaybackmode:i:1;audiomode:i:0;devicestoredirect:s:*;drivestoredirect:s:*;redirectclipboard:i:1;redirectcomports:i:1;redirectprinters:i:1;redirectsmartcards:i:1;redirectwebauthn:i:1;usbdevicestoredirect:s:*;use multimon:i:1;"
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avdPoolRegInfo" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdPool.id
  expiration_date = timeadd(local.current_time, local.expiration_duration)
}

resource "azurerm_virtual_desktop_application_group" "avdAppGroup" {
  name                         = var.avdAppGroupName
  location                     = var.location
  resource_group_name          = azurerm_resource_group.avdRG.name
  type                         = "Desktop"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.avdPool.id
  friendly_name                = var.avdAppGroupFriendlyName
  description                  = var.avdAppGroupDescription
  tags                         = var.avdTags
  default_desktop_display_name = var.avdAppSessionDesktopFriendlyName
}

resource "azurerm_virtual_desktop_workspace" "avdWorkspace" {
  name                = var.avdWorkspaceName
  location            = var.location
  resource_group_name = azurerm_resource_group.avdRG.name # Ensure this references the correct RG
  friendly_name       = var.avdWorkspaceFriendlyName
  description         = var.avdWorkspaceDescription
  tags                = var.avdTags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avdGroupAssociation" {
  workspace_id         = azurerm_virtual_desktop_workspace.avdWorkspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avdAppGroup.id
}

resource "random_string" "avdSuffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_storage_account" "avdStorage" {
  name                     = "${var.avdSAName}${lower(replace(var.location, " ", ""))}${random_string.avdSuffix.result}"
  resource_group_name      = azurerm_resource_group.avdRG.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = var.avdTags
}

resource "azurerm_network_interface" "avdNIC" {
  count               = var.avdSessionHostCount # Adjust count to match the number of VMs/session hosts
  name                = format("${var.avdSessionHostPrefix}-%03d-nic", count.index + 1)
  location            = var.location
  resource_group_name = azurerm_resource_group.avdRG.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.avdSubnet.id #var.avdSubnetID
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.avdTags
}

resource "azurerm_windows_virtual_machine" "avdSessionHost" {
  count               = var.avdSessionHostCount                                     # Number of session hosts to create
  name                = format("${var.avdSessionHostPrefix}-%03d", count.index + 1) # Generates avd-host-001, avd-host-002, ...
  resource_group_name = azurerm_resource_group.avdRG.name
  location            = var.location
  size                = var.avdSessionHostSize
  admin_username      = var.avdSessionHostAdminUser
  admin_password      = var.avdSessionHostPassword

  network_interface_ids = [azurerm_network_interface.avdNIC[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = format("${var.avdSessionHostPrefix}-%03d-osdisk", count.index + 1)
  }
  source_image_reference {
    publisher = var.avdImageReference.publisher
    offer     = var.avdImageReference.offer
    sku       = var.avdImageReference.sku
    version   = var.avdImageReference.version
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.avdStorage.primary_blob_endpoint
  }
  tags = var.avdTags
}

resource "azurerm_virtual_machine_extension" "vmext_dsc" { #reference
  count                      = var.avdSessionHostCount
  name                       = "${format("${var.avdSessionHostPrefix}-%03d", count.index + 1)}-avd_dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdSessionHost.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true
  tags                       = var.avdTags
  settings                   = <<-SETTINGS
    {
      "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "HostPoolName":"${azurerm_virtual_desktop_host_pool.avdPool.name}"
      }
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "properties": {
      "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.avdPoolRegInfo.token}"
    }
  }
PROTECTED_SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.avdDomainJoin,
    azurerm_virtual_desktop_host_pool.avdPool
  ]
}

resource "azurerm_virtual_machine_extension" "avdDomainJoin" {
  count                = length(azurerm_windows_virtual_machine.avdSessionHost.*.id)
  name                 = "domainJoinExtension"
  virtual_machine_id   = azurerm_windows_virtual_machine.avdSessionHost[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
    {
      "Name": "${var.domainJoinDomain}",
      "OUPath": "${var.domainJoinOU}",
      "User": "${var.domainJoinUser}",
      "Restart": "true",
      "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password": "${var.domainJoinPassword}"
    }
PROTECTED_SETTINGS
  tags               = var.avdTags
}

# resource "azurerm_virtual_machine_extension" "AVDHostArcEnrollment" {
#   count                = length(var.NITTSSServerNames)
#   name                 = "arcEnrollment"
#   virtual_machine_id   = azurerm_windows_virtual_machine.NITTSSServer[count.index].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

# #   settings           = <<SETTINGS
# #     {
# #       "commandToExecute": "powershell -Command \"Invoke-WebRequest -Uri https://aka.ms/azcmagent -OutFile C:\\install_azcmagent.ps1; C:\\install_azcmagent.ps1 -ServicePrincipal -TenantId '${data.azurerm_client_config.current.tenant_id}' -ClientId '${var.arcServicePrincipalID}' -ClientSecret '${var.arcServicePrincipalPassword}' -Location '${var.location}' -Force\""
# #     }
# # SETTINGS
#   protected_settings = <<PROTECTED_SETTINGS
#     {
#       "commandToExecute": "powershell -Command \"C:\\install_azcmagent.ps1 -ServicePrincipal -TenantId '${data.azurerm_client_config.current.tenant_id}' -ClientId '${var.arcServicePrincipalID}' -ClientSecret '${var.arcServicePrincipalPassword}' -Location '${var.location}' -Force\""
#     }
# PROTECTED_SETTINGS
#   tags               = var.coreTags
# }
