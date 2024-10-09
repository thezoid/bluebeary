resource "azurerm_key_vault" "sharedKV" {
  name                       = var.keyVaultName
  location                   = var.location
  resource_group_name        = azurerm_resource_group.sharedRG.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
  tags = var.coreTags
}

# resource "azurerm_public_ip" "bastionPIP" {
#   name                = "${var.bastionName}-PIP"
#   location            = var.location
#   resource_group_name = var.sharedRGName
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   tags                = var.coreTags
# }

# resource "azurerm_bastion_host" "bastion" {
#   name                = var.bastionName
#   location            = var.location
#   resource_group_name = var.sharedRGName

#   ip_configuration {
#     name                 = "configuration"
#     subnet_id            = azurerm_subnet.bastionSubnet.id
#     public_ip_address_id = azurerm_public_ip.bastionPIP.id
#   }
#   tags = var.coreTags
# }

resource "azurerm_network_interface" "ServerNIC" {
  count               = length(var.ServerNames) # Adjust count to match the number of VMs/session hosts
  name                = "${var.ServerNames[count.index]}-NIC"
  location            = var.location
  resource_group_name = azurerm_resource_group.sharedRG.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.sharedServicesSubnet.id #var.avdSubnetID
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ServerIPs[count.index]
  }
}

resource "azurerm_windows_virtual_machine" "Server" {
  count               = length(var.ServerNames)      # Number of session hosts to create
  name                = var.ServerNames[count.index] # Generates avd-host-001, avd-host-002, ...
  resource_group_name = azurerm_resource_group.sharedRG.name
  location            = var.location
  size                = var.ServerSize
  admin_username      = var.avdSessionHostAdminUser
  admin_password      = var.avdSessionHostPassword

  network_interface_ids = [azurerm_network_interface.ServerNIC[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.ServerNames[count.index]}-osdisk"
  }

  source_image_reference {
    publisher = var.ServerImageReference.publisher
    offer     = var.ServerImageReference.offer
    sku       = var.ServerImageReference.sku
    version   = var.ServerImageReference.version
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.coreStorage.primary_blob_endpoint
  }
  tags = var.coreTags
}

resource "azurerm_virtual_machine_extension" "ServerDomainJoin" {
  count                = length(var.ServerNames)
  name                 = "domainJoinExtension"
  virtual_machine_id   = azurerm_windows_virtual_machine.Server[count.index].id
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
  tags               = var.coreTags
}

# resource "azurerm_virtual_machine_extension" "serverArcEnrollment" {
#   count                = length(var.ServerNames)
#   name                 = "arcEnrollment"
#   virtual_machine_id   = azurerm_windows_virtual_machine.Server[count.index].id
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

resource "random_string" "coreSuffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_storage_account" "coreStorage" {
  name                     = "${var.avdSAName}${lower(replace(var.location, " ", ""))}${random_string.coreSuffix.result}"
  resource_group_name      = azurerm_resource_group.sharedRG.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = var.coreTags
}
