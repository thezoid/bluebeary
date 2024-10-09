resource "azurerm_resource_group" "sharedRG" {
  name     = var.sharedRGName
  location = var.location
  tags     = var.coreTags
}

resource "azurerm_resource_group" "networkRG" {
  name     = var.networkRGName
  location = var.location
  tags     = var.coreTags
}

resource "azurerm_resource_group" "monitoringRG" {
  name     = var.monitoringRGName
  location = var.location
  tags     = var.coreTags
}