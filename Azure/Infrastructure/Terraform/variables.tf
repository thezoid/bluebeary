variable "sharedRGName" {
  description = "The name of the shared resource group"
  type        = string
}

variable "networkRGName" {
  description = "The name of the network resource group"
  type        = string
}

variable "monitoringRGName" {
  description = "The name of the monitoring resource group"
  type        = string
}

variable "RGName" {
  description = "The name of the monitoring resource group"
  type        = string
}

variable "avdRGName" {
  description = "The name of the AVD resource group"
  type        = string
}

variable "location" {
  description = "The Azure region where the resources will be created"
  type        = string
}

variable "vwanName" {
  description = "The name of the Virtual WAN"
  type        = string
}

variable "vwanHubAddressPrefix" {
  description = "The IP address space of the vwan hub"
  type        = string
}

variable "sharedServicesVnetName" {
  description = "The name of the shared services Virtual Network"
  type        = string
}

variable "sharedServicesVnetAddressSpace" {
  description = "The address space for the shared services Virtual Network"
  type        = string
}

variable "sharedServicesVnetSubnetName" {
  description = "The names of the subnets within the shared services Virtual Network"
  type        = string
}

variable "sharedServicesVnetSubnetPrefix" {
  description = "The address prefixes for the subnets within the shared services Virtual Network"
  type        = string
}

variable "bastionName" {
  description = "The name of the shared services Virtual Network"
  type        = string
}

variable "bastionSubnetName" {
  description = "The names of the subnets within the shared services Virtual Network"
  type        = string
}

variable "bastionSubnetPrefix" {
  description = "The address prefixes for the subnets within the shared services Virtual Network. NOTE: must be at least a /26"
  type        = string
}

variable "AFWName" {
  description = "The name of the Azure Firewall instance"
  type        = string
}

variable "AFWPIPCount" {
  description = "The number of the Azure Firewall public IPs"
  type        = number
}

variable "VGWName" {
  description = "The name of the VPN Gateway"
  type        = string
}

variable "VGWNameScaleUnit" {
  description = "The scale unit for the VPN Gateway"
  type        = number
}

variable "LNGName" {
  description = "The name of the local network gateway for S2S connection"
  type        = string
}

variable "LNPIP" {
  description = "The public IP address of the local network gateway"
  type        = string
}

# variable "localNetworkAddressSpace" {
#   description = "The address space of the on-premises network"
#   type        = list(string)
# }
variable "BGPASN" {
  description = "The S2S BGP ASN"
  type        = string
}

variable "BGPPeerAddress" {
  description = "The S2S BGP Peer IP"
  type        = string
}

variable "S2SConnectionName" {
  description = "The name of the S2S VPN connection"
  type        = string
}

variable "S2SPresharedKey" {
  description = "The shared key for the S2S VPN connection"
  type        = string
}

variable "keyVaultName" {
  description = "The name of the Azure Key Vault"
  type        = string
}

variable "avdSubnetName" {
  description = "The name of the AVD subnet"
  type        = string
}

variable "avdSubnetPrefix" {
  description = "the ip address space of the subnet"
  type        = string
}

variable "avdSAName" {
  description = "The name of the AVD storage account"
  type        = string
}

variable "avdPoolName" {
  description = "The name of the AVD Host Pool"
  type        = string
}

variable "avdPoolFriendlyName" {
  description = "The displayed value of the host pool (human readable)"
  type        = string
}

variable "avdPoolDescription" {
  description = "The displayed description of the pool - include purpose and who may be using it"
  type        = string
}

variable "avdAppGroupName" {
  description = "The name of the AVD app group"
  type        = string
}

variable "avdAppGroupFriendlyName" {
  description = "The displayed value of the app group (human readable)"
  type        = string
}

variable "avdAppSessionDesktopFriendlyName" {
  description = "The displayed value of the app group (human readable)"
  type        = string
}

variable "avdAppGroupDescription" {
  description = "The displayed description of the app group - include purpose and who may be using it"
  type        = string
}

variable "avdWorkspaceName" {
  description = "The name of the AVD workspace"
  type        = string
}

variable "avdWorkspaceFriendlyName" {
  description = "The displayed value of the workspace (human readable)"
  type        = string
}

variable "avdWorkspaceDescription" {
  description = "The displayed description of the workspace - include purpose and who may be using it"
  type        = string
}

variable "avdSessionHostPrefix" {
  description = "The name of the session host with no indexing"
  default     = "az-avd"
  type        = string
  validation {
    condition     = length(var.avdSessionHostPrefix) <= 11
    error_message = "The avdSessionHostPrefix must be 11 or fewer characters to account for indexing"
  }
}

variable "avdSessionHostCount" {
  description = "The name of the session host with no indexing"
  type        = number
}

variable "avdSessionHostSize" {
  description = "The AZ VM size"
  type        = string
  default     = "Standard_B2ms"
}

variable "avdSessionHostAdminUser" {
  description = "The device admin username to use during deployment"
  default     = "deploymentadmin"
  type        = string
}

variable "avdSessionHostPassword" {
  description = "The device admin password to use during deployment"
  type        = string
  sensitive   = true
}

variable "avdSubnetID" {
  description = "The resource ID of the AVD subnet"
  type        = string
  default     = "/subscriptions/<sub id>/resourceGroups/<RG name>/providers/Microsoft.Network/virtualNetworks/<vnet name>/subnets/<subnet name>"
}

variable "avdSessionHostRegistrationToken" {
  description = "The host pool registration code"
  type        = string
  sensitive   = true
}

variable "domainJoinDomain" {
  description = "Your AD domain"
  type        = string
  default     = "ad.example.com"
}

variable "domainJoinOU" {
  description = "The OU to join hosts into"
  type        = string
  default     = "OU=Computers,DC=ad,DC=example,DC=com"
}

variable "domainJoinUser" {
  description = "The username to use in the domain join"
  type        = string
}

variable "domainJoinPassword" {
  description = "The password to use for the domain join account"
  type        = string
  sensitive   = true
}

variable "arcServicePrincipalID" {
  description = "value"
  type        = string
}

variable "arcServicePrincipalPassword" {
  description = "value"
  type        = string
  sensitive   = true
}

variable "avdPoolMaxConcurrentSessions" {
  description = "0 to 999999 for the maximum number of users that have concurrent sessions on a session host"
  type        = number
  default     = 10
}

variable "avdImageReference" {
  description = "The source image reference for the VM."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-23h2-avd"
    version   = "latest"
  }
}

variable "ServerImageReference" {
  description = "The source image reference for the VM."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

variable "ServerIPs" {
  description = "A list of the IPs to use for the server deployments - match the order of the names"
  type        = list(string)
}

variable "ServerNames" {
  description = "A list of the names to use for the server deployments - match the order of the IPs"
  type        = list(string)
}

variable "ServerSize" {
  description = "The AZ VM size"
  type        = string
  default     = "Standard_B2ms"
}

variable "coreTags" {
  description = "A map of tags to apply to all resources. Must include FISMA ID, System Name, System Owner, Technical Owner, Environment, and Location."
  type        = map(string)
  validation {
    condition = (
      contains(keys(var.coreTags), "system_id") &&
      contains(keys(var.coreTags), "system_name") &&
      contains(keys(var.coreTags), "system_owner") &&
      contains(keys(var.coreTags), "technical_owner") &&
      contains(keys(var.coreTags), "environment") &&
      contains(keys(var.coreTags), "location") &&
      #can(regex("^[\\w-\\.]+@[\\w-]+\\.[\\w-]{2,4}$", var.coreTags["system_owner"])) &&
      #can(regex("^[\\w-\\.]+@[\\w-]+\\.[\\w-]{2,4}$", var.coreTags["technical_owner"])) &&
      contains(keys(var.coreTags), "project") &&
      contains(keys(var.coreTags), "created_by") &&
      #can(regex("^[\\w-\\.]+@[\\w-]+\\.[\\w-]{2,4}$", var.coreTags["created_by"])) &&
      contains(keys(var.coreTags), "compliance") &&
      contains(keys(var.coreTags), "department") &&
      contains(keys(var.coreTags), "business_unit")
    )
    error_message = "All required tags (systemID, systemName, systemOwner, technicalOwner, environment, location, project, createdBy, compliance, department, businessUnit) must be included in the 'tags' variable."
  }
}

variable "avdTags" {
  description = "A map of tags to apply to all resources. Must include FISMA ID, System Name, System Owner, Technical Owner, Environment, and Location."
  type        = map(string)
  validation {
    condition = (
      contains(keys(var.avdTags), "system_id") &&
      contains(keys(var.avdTags), "system_name") &&
      contains(keys(var.avdTags), "system_owner") &&
      contains(keys(var.avdTags), "technical_owner") &&
      contains(keys(var.avdTags), "environment") &&
      contains(keys(var.avdTags), "location") &&
      #can(regex("^[\\w-\\.]+@[\\w-]+\\.[\\w-]{2,4}$", var.avdTags["system_owner"])) &&
      #can(regex("^[\\w-\\.]+@[\\w-]+\\.[\\w-]{2,4}$", var.avdTags["technical_owner"])) &&
      contains(keys(var.avdTags), "project") &&
      contains(keys(var.avdTags), "created_by") &&
      #can(regex("^[\\w-\\.]+@[\\w-]+\\.[\\w-]{2,4}$", var.avdTags["created_by"])) &&
      contains(keys(var.avdTags), "compliance") &&
      contains(keys(var.avdTags), "department") &&
      contains(keys(var.avdTags), "business_unit")
    )
    error_message = "All required tags (systemID, systemName, systemOwner, technicalOwner, environment, location, project, createdBy, compliance, department, businessUnit) must be included in the 'tags' variable."
  }
}


