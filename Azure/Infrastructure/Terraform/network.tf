resource "azurerm_virtual_wan" "vwan" {
  name                = var.vwanName
  resource_group_name = azurerm_resource_group.networkRG.name
  location            = var.location
  type                = "Standard"
  tags                = var.coreTags
}

resource "azurerm_virtual_hub" "vwanHub" {
  name                   = "${var.vwanName}-Hub"
  resource_group_name    = azurerm_resource_group.networkRG.name
  location               = var.location
  virtual_wan_id         = azurerm_virtual_wan.vwan.id
  address_prefix         = var.vwanHubAddressPrefix
  tags                   = var.coreTags
  hub_routing_preference = "VpnGateway"
}

resource "azurerm_virtual_network" "sharedServicesVnet" {
  name                = var.sharedServicesVnetName
  resource_group_name = azurerm_resource_group.networkRG.name
  location            = var.location
  address_space       = [var.sharedServicesVnetAddressSpace]
  tags                = var.coreTags
}

resource "azurerm_subnet" "sharedServicesSubnet" {
  name                 = var.sharedServicesVnetSubnetName
  resource_group_name  = azurerm_resource_group.networkRG.name
  virtual_network_name = azurerm_virtual_network.sharedServicesVnet.name
  address_prefixes     = [var.sharedServicesVnetSubnetPrefix]

}

# resource "azurerm_subnet" "bastionSubnet" {
#   name                 = var.bastionSubnetName
#   resource_group_name  = azurerm_resource_group.networkRG.name
#   virtual_network_name = azurerm_virtual_network.sharedServicesVnet.name
#   address_prefixes     = [var.bastionSubnetPrefix]
# }

resource "azurerm_virtual_hub_connection" "vnetToVwanPeering" {
  name                      = "${var.sharedServicesVnetName}-to-${var.vwanName}"
  virtual_hub_id            = azurerm_virtual_hub.vwanHub.id
  remote_virtual_network_id = azurerm_virtual_network.sharedServicesVnet.id
  internet_security_enabled = true
}

resource "azurerm_vpn_gateway" "hubVGW" {
  name                = var.VGWName
  location            = var.location
  resource_group_name = azurerm_resource_group.networkRG.name
  virtual_hub_id      = azurerm_virtual_hub.vwanHub.id
  scale_unit          = var.VGWNameScaleUnit
  tags                = var.coreTags
}

# resource "azurerm_local_network_gateway" "hubLNG" {
#   name                = var.LNGName
#   location            = var.location
#   resource_group_name = azurerm_resource_group.networkRG.name
#   gateway_address     = var.LNPIP
#   # address_space       = var.localNetworkAddressSpace
#   bgp_settings {
#     asn                 = var.BGPASN
#     bgp_peering_address = var.BGPPeerAddress
#   }
#   tags = var.coreTags
# }

# resource "azurerm_vpn_site" "hubVPNSite" {
#   name                = "${var.vwanName}-OnPrem-VPN-Site"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.networkRG.name
#   virtual_wan_id      = azurerm_virtual_wan.vwan.id
#   link {
#     name       = "primary"
#     ip_address = var.LNPIP
#     bgp{
#       asn = var.BGPASN
#       peering_address = var.BGPPeerAddress
#     }
#   }
#   tags = var.coreTags
# }

# resource "azurerm_vpn_gateway_connection" "S2SConnection" {
#   name               = var.S2SConnectionName
#   vpn_gateway_id     = azurerm_vpn_gateway.hubVGW.id
#   remote_vpn_site_id = azurerm_vpn_site.hubVPNSite.id
#   vpn_link {
#     name             = "primary-link-connection"
#     vpn_site_link_id = azurerm_vpn_site.hubVPNSite.link[0].id
#     shared_key       = var.S2SPresharedKey
#   }
# }

resource "azurerm_network_security_group" "coreNSG" {
  name                = "NSG-EUS2-Prod-Core-01"
  location            = var.location
  resource_group_name = var.networkRGName
  tags                = var.coreTags
}

# Default deny rules
resource "azurerm_network_security_rule" "deny_inbound" {
  name                        = "deny-inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.networkRGName
  network_security_group_name = azurerm_network_security_group.coreNSG.name
}

resource "azurerm_network_security_rule" "deny_outbound" {
  name                        = "deny-outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.networkRGName
  network_security_group_name = azurerm_network_security_group.coreNSG.name
}

# Combined allow rule for AD, SCCM, and common Windows ports
resource "azurerm_network_security_rule" "allow_common_windows_ports" {
  name              = "AllowWindowsCommonPortsIn"
  priority          = 100
  direction         = "Inbound"
  access            = "Allow"
  protocol          = "Tcp"
  source_port_range = "*"
  destination_port_ranges = [
    "53",   # DNS: Domain Name System
    "88",   # Kerberos: Authentication protocol
    "123",  # NTP: Network Time Protocol
    "135",  # RPC: Remote Procedure Call
    "139",  # NetBIOS/SMB: Session services
    "389",  # LDAP: Lightweight Directory Access Protocol
    "445",  # SMB over IP (Microsoft-DS): File sharing, network browsing
    "464",  # Kerberos pwd
    "636",  # LDAPS: LDAP over SSL/TLS
    "3268", # Global Catalog: LDAP for AD global catalog
    "3269", # LDAPS for Global Catalog
    "5722", # DFS-R: Distributed File System Replication
    "5985", # WinRM HTTP: Windows Remote Management
    "5986", # WinRM HTTPS: Windows Remote Management over HTTPS
    "8530", # WSUS HTTP: Windows Server Update Services
    "8531"  # WSUS HTTPS: Windows Server Update Services over HTTPS
  ]
  source_address_prefix       = "10.0.0.0/8"
  destination_address_prefix  = "*"
  resource_group_name         = var.networkRGName
  network_security_group_name = azurerm_network_security_group.coreNSG.name
}

resource "azurerm_network_security_rule" "allow_mgm_ports_in" {
  name              = "AllowMGMTIn"
  priority          = 101
  direction         = "Inbound"
  access            = "Allow"
  protocol          = "Tcp"
  source_port_range = "*"
  destination_port_ranges = [
    "22",  #ssh
    "3389" #rdp
  ]
  source_address_prefixes = [
    "10.0.0.0/8",
  ]
  destination_address_prefix  = "*"
  resource_group_name         = var.networkRGName
  network_security_group_name = azurerm_network_security_group.coreNSG.name
}

resource "azurerm_network_security_rule" "allow_common_windows_ports_out" {
  name              = "AllowWindowsCommonPortsOut"
  priority          = 100
  direction         = "Outbound"
  access            = "Allow"
  protocol          = "Tcp"
  source_port_range = "*"
  destination_port_ranges = [
    "53",   # DNS: Domain Name System
    "88",   # Kerberos: Authentication protocol
    "135",  # RPC: Remote Procedure Call
    "139",  # NetBIOS/SMB: Session services
    "389",  # LDAP: Lightweight Directory Access Protocol
    "445",  # SMB over IP (Microsoft-DS): File sharing, network browsing
    "636",  # LDAPS: LDAP over SSL/TLS
    "3268", # Global Catalog: LDAP for AD global catalog
    "3269", # LDAPS for Global Catalog
    "5722", # DFS-R: Distributed File System Replication
    "5985", # WinRM HTTP: Windows Remote Management
    "5986", # WinRM HTTPS: Windows Remote Management over HTTPS
    "8530", # WSUS HTTP: Windows Server Update Services
    "8531"  # WSUS HTTPS: Windows Server Update Services over HTTPS
  ]
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.0.0/8"
  resource_group_name         = var.networkRGName
  network_security_group_name = azurerm_network_security_group.coreNSG.name
}

# Combined allow outbound rule for HTTP and HTTPS
resource "azurerm_network_security_rule" "allow_outbound_http_https" {
  name                        = "Allow-Outbound-HTTP-HTTPS"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.networkRGName
  network_security_group_name = azurerm_network_security_group.coreNSG.name
}

resource "azurerm_subnet_network_security_group_association" "coreNSGToSharedServicesSubnet" {
  subnet_id                 = azurerm_subnet.sharedServicesSubnet.id
  network_security_group_id = azurerm_network_security_group.coreNSG.id
}
