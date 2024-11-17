

# Add Front Door Profile
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard_AzureFrontDoor"
}

# Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

# Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    protocol            = "Http"
    interval_in_seconds = 100
  }
}

# Origin pointing to our existing Load Balancer
resource "azurerm_cdn_frontdoor_origin" "this" {
  name                           = var.name
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                        = true
  certificate_name_check_enabled = true

  host_name  = azurerm_public_ip.this.ip_address
  http_port  = 80
  https_port = 443
  priority   = 1
  weight     = 1000
}

# Custom Domain configuration
resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  host_name                = var.domain_name # our subdomain

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

# Route configuration
resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = var.name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                       = true

  patterns_to_match        = ["/*"]
  supported_protocols      = ["Http", "Https"]
  cdn_frontdoor_origin_ids = [azurerm_cdn_frontdoor_origin.this.id]

  link_to_default_domain = true
  https_redirect_enabled = true

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.this.id]
}

# Reference the existing DNS zone using a data source
data "azurerm_dns_zone" "existing" {
  provider            = azurerm.dns # DNS is in another resource group
  name                = "azure.joshuamkite.co.uk"
  resource_group_name = "dns"
}

resource "azurerm_dns_txt_record" "validation" {
  provider            = azurerm.dns # Use same provider as DNS zone
  name                = join(".", ["_dnsauth", "hello-world"])
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 30
  record {
    value = azurerm_cdn_frontdoor_custom_domain.this.validation_token
  }
}

# Front Door validation CNAME record
resource "azurerm_dns_cname_record" "validation" {
  provider            = azurerm.dns
  name                = "afdverify.hello-world"
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 30
  record              = "afdverify.${azurerm_cdn_frontdoor_endpoint.this.host_name}"
}


# Create the CNAME record using the data source reference
resource "azurerm_dns_cname_record" "this" {
  provider            = azurerm.dns # Use same provider as DNS zone
  name                = "hello-world"
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 30
  record              = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "dns_record" {
  value = azurerm_dns_cname_record.this.fqdn
}
