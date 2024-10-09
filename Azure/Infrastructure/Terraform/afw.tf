resource "azurerm_firewall_policy" "hubFWpolicy" {
  name                = "${var.AFWName}-Policy"
  resource_group_name = azurerm_resource_group.networkRG.name
  location            = var.location
  tags                = var.coreTags
  insights {
    default_log_analytics_workspace_id = "<law id here>"
    enabled                            = true
    retention_in_days                  = 365
  }
}

resource "azurerm_firewall" "hubFW" {
  depends_on          = [azurerm_firewall_policy.hubFWpolicy]
  name                = var.AFWName
  resource_group_name = azurerm_resource_group.networkRG.name
  location            = var.location
  firewall_policy_id  = azurerm_firewall_policy.hubFWpolicy.id
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.vwanHub.id
    public_ip_count = var.AFWPIPCount
  }
  tags  = var.coreTags
  zones = ["1", "2", "3"]

}

resource "azurerm_firewall_policy_rule_collection_group" "hubFWPolicyRuleCollection" {
  name               = "${azurerm_firewall_policy.hubFWpolicy.name}-PRCG"
  firewall_policy_id = azurerm_firewall_policy.hubFWpolicy.id
  priority           = 500

  application_rule_collection {
    name     = "AzurePlatformTags"
    priority = 1100
    action   = "Allow"
    rule {
      name = "AzurePlatformTags"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = ["10.0.0.0/8"]
      destination_fqdn_tags = [ #reference: https://learn.microsoft.com/en-us/azure/firewall/fqdn-tags
        "Windows365",
        "WindowsUpdate",
        "MicrosoftActiveProtectionService",
        "AzureBackup",
        "WindowsVirtualDesktop",
        "Office365",
        "MicrosoftIntune"
      ]
    }
  }

  application_rule_collection {
    name     = "TrustedDomainURLs"
    priority = 1101
    action   = "Allow"
    rule {
      name = "example-com"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.0.0.0/19"]
      destination_fqdns = ["*.example.com"]
    }
  }

  network_rule_collection {
    name     = "DenyCoreDefaultCollection"
    priority = 65000
    action   = "Deny"
    rule {
      name                  = "DenyAllTraffic"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_ports     = ["*"]
      destination_addresses = ["*"]
      description           = "Default rule to deny all traffic"
    }
  }

  network_rule_collection {
    name     = "AllowCoreDefaultCollection"
    priority = 1000
    action   = "Allow"
    rule {
      name                  = "AllowHTTP"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_ports     = ["80"]
      destination_addresses = ["0.0.0.0/0"]
      # description           = "Allow HTTP traffic"
    }
    rule {
      name                  = "AllowHTTPS"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_ports     = ["443"]
      destination_addresses = ["0.0.0.0/0"]
      # description           = "Allow HTTPS traffic"
    }
    rule {
      name                  = "AllowRDP"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["192.168.1.0/24"]
      destination_ports     = ["3389"]
      destination_addresses = ["10.0.2.0/19", "192.168.1.0/24"]
      # description           = "Allow RDP traffic"
    }
    rule {
      name                  = "AllowSSH"
      protocols             = ["TCP"]
      source_addresses      = ["192.168.1.0/24"]
      destination_ports     = ["22"]
      destination_addresses = ["10.0.2.0/19"]
      # description           = "Allow inbound SSH traffic"
    }
    rule {
      name              = "AllowCommonAzureServicetags"
      protocols         = ["TCP"]
      source_addresses  = ["10.0.0.0/8"]
      destination_ports = ["*"]
      destination_addresses = [ #reference: https://learn.microsoft.com/en-us/azure/virtual-network/service-tags-overview#available-service-tags
        "AzureActiveDirectory",
        "AzureArcInfrastructure",
        "AzureBackup",
        "AzureCloud",
        "AzureMachineLearning",
        "AzureMonitor",
        "AzureSentinel",
        "AzureResourceManager",
        "AzureSiteRecovery",
        "AzureKeyVault",
        "EventHub",
        "GuestAndHybridManagement",
        "Storage",
        "MicrosoftDefenderForEndpoint",
        "WindowsVirtualDesktop",
        "VirtualNetwork"
      ]
      # description           = "Allow inbound SSH traffic"
    }
    rule {
      name                  = "AllowADCommonPorts"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports = [
        "53",         # DNS: Domain Name System
        "88",         # Kerberos: Authentication protocol
        "135",        # RPC: Remote Procedure Call
        "139",        # NetBIOS/SMB: Session services
        "389",        # LDAP: Lightweight Directory Access Protocol
        "445",        # SMB over IP (Microsoft-DS): File sharing, network browsing
        "636",        # LDAPS: LDAP over SSL/TLS
        "3268",       # Global Catalog: LDAP for AD global catalog
        "3269",       # LDAPS for Global Catalog
        "5722",       # DFS-R: Distributed File System Replication
        "5985",       # WinRM HTTP: Windows Remote Management
        "5986",       # WinRM HTTPS: Windows Remote Management over HTTPS
        "8530",       # WSUS HTTP: Windows Server Update Services
        "8531",       # WSUS HTTPS: Windows Server Update Services over HTTPS
        "135",        #rpc
        "49152-65535" #rpc dynamic ports
      ]
      # description = "Allow common AD ports"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "DefaultDenyAll" {
  name                = "DenyCoreDefaultCollection"
  azure_firewall_name = azurerm_firewall.hubFW.name
  resource_group_name = azurerm_resource_group.networkRG.name
  priority            = 65000
  action              = "Deny"

  rule {
    name                  = "DenyAllTraffic"
    protocols             = ["Any"]
    source_addresses      = ["*"]
    destination_ports     = ["*"]
    destination_addresses = ["*"]
    description           = "Default rule to deny all traffic"
  }
}

