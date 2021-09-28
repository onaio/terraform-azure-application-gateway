# since these variables are re-used - a locals block makes this more maintainable
locals {
  http_frontend_port_name         = "${var.application_gateway_name}-http-port"
  https_frontend_port_name        = "${var.application_gateway_name}-https-port"
  frontend_ip_configuration_name  = "${var.application_gateway_name}-feip"
  http_listener_name              = "${var.application_gateway_name}-httplstn"
  https_listener_name             = "${var.application_gateway_name}-httpslstn"
  http_request_routing_rule_name  = "${var.application_gateway_name}-http-rqrt"
  https_request_routing_rule_name = "${var.application_gateway_name}-https-rqrt"
  http_setting_name               = "${var.application_gateway_name}-be-http-st"
  redirect_configuration_name     = "${var.application_gateway_name}-rdrcfg"
}

data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "existing" {
  name                = var.virtual_network_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

data "azurerm_key_vault_certificate" "existing" {
  count        = length(var.key_vault_ssl_certificates)
  key_vault_id = var.key_vault_id
  name         = var.key_vault_ssl_certificates[count.index]
}

data "azurerm_subnet" "frontend" {
  name                 = var.frontend_subnet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = data.azurerm_virtual_network.existing.name
}

data "azurerm_subnet" "backend" {
  name                 = var.backend_subnet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = data.azurerm_virtual_network.existing.name
}

resource "azurerm_public_ip" "frontend" {
  name                = "${var.application_gateway_name}-pip"
  domain_name_label   = var.public_ip_domain_name_label
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  allocation_method   = var.application_gateway_sku_tier == "Standard" ? "Dynamic" : "Static"
  sku                 = var.application_gateway_sku_tier == "Standard" ? "Basic" : "Standard"
}

resource "azurerm_user_assigned_identity" "keyvault" {
  count               = length(var.key_vault_ssl_certificates) > 0 ? 1 : 0
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location

  name = "${var.application_gateway_name}-keyvault"
}

resource "azurerm_application_gateway" "main" {
  name                = var.application_gateway_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location

  sku {
    name     = var.application_gateway_sku_name
    tier     = var.application_gateway_sku_tier
    capacity = var.application_gateway_sku_capacity
  }

  frontend_port {
    name = local.http_frontend_port_name
    port = var.frontend_http_port
  }

  frontend_port {
    name = local.https_frontend_port_name
    port = var.frontend_https_port
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.frontend.id
  }

  gateway_ip_configuration {
    name      = "${var.application_gateway_name}-gwic"
    subnet_id = data.azurerm_subnet.frontend.id
  }

  waf_configuration {
    enabled                  = var.waf_enabled
    firewall_mode            = var.waf_firewall_mode
    rule_set_type            = var.waf_rule_set_type
    rule_set_version         = var.waf_rule_set_version
    file_upload_limit_mb     = var.waf_file_upload_limit_mb
    request_body_check       = var.waf_request_body_check
    max_request_body_size_kb = var.waf_max_request_body_size_kb
  }

  dynamic "ssl_certificate" {
    for_each = data.azurerm_key_vault_certificate.existing
    content {
      name                = ssl_certificate.value.name
      key_vault_secret_id = ssl_certificate.value.secret_id
      data                = null
      password            = null
    }
  }

  dynamic "ssl_certificate" {
    for_each = var.ssl_certificates
    content {
      name                = ssl_certificate.value.name
      data                = ssl_certificate.value.pfx_data
      password            = ssl_certificate.value.pfx_password
      key_vault_secret_id = null
    }
  }

  dynamic "ssl_profile" {
    for_each = data.azurerm_key_vault_certificate.existing
    content {
      name = ssl_profile.value.name
      trusted_client_certificate_names = [ssl_profile.value.name]
      verify_client_cert_issuer_dn = false
      ssl_policy {
        cipher_suites      = []
        disabled_protocols = []
        policy_name        = "AppGwSslPolicy20170401"
        policy_type        = "Predefined"
      }
    }
  }

  dynamic "identity" {
    for_each = length(var.key_vault_ssl_certificates) > 0 ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.keyvault[0].id]
    }
  }

  dynamic "backend_address_pool" {
    for_each = var.backend_address_pools
    content {
      name         = backend_address_pool.value.name
      ip_addresses = backend_address_pool.value.ip_addresses
      fqdns        = backend_address_pool.value.fqdns
    }
  }

  dynamic "trusted_client_certificate" {
    for_each = data.azurerm_key_vault_certificate.existing
    content {
      name = trusted_client_certificate.value.name
      data = trusted_client_certificate.value.certificate_data_base64
    }
  }

  dynamic "http_listener" {
    for_each = var.http_listeners
    content {
      name                           = http_listener.value.name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = http_listener.value.ssl_certificate_name != null ? local.https_frontend_port_name : local.http_frontend_port_name
      protocol                       = http_listener.value.ssl_certificate_name != null ? "Https" : "Http"
      ssl_certificate_name           = http_listener.value.ssl_certificate_name
      # The host_names and host_name are mutually exclusive and cannot both be set.
      host_name  = length(http_listener.value.host_names) > 1 ? null : element(http_listener.value.host_names, 0)
      host_names = length(http_listener.value.host_names) > 1 ? http_listener.value.host_names : null
      require_sni = (http_listener.value.ssl_certificate_name != null ?
        http_listener.value.require_sni :
      null)
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.backend_http_settings
    content {
      name                                = backend_http_settings.value.name
      cookie_based_affinity               = backend_http_settings.value.enable_cookie_based_affinity ? "Enabled" : "Disabled"
      path                                = backend_http_settings.value.path
      port                                = backend_http_settings.value.port
      protocol                            = backend_http_settings.value.protocol
      request_timeout                     = backend_http_settings.value.request_timeout
      probe_name                          = backend_http_settings.value.probe_name
      host_name                           = backend_http_settings.value.host_name
      pick_host_name_from_backend_address = backend_http_settings.value.pick_host_name_from_backend_address
    }
  }
  dynamic "probe" {
    for_each = var.probes
    content {
      name                = probe.value.name
      path                = probe.value.path
      protocol            = probe.value.protocol
      interval            = probe.value.interval
      timeout             = probe.value.timeout
      unhealthy_threshold = probe.value.unhealthy_threshold
      match {
        body        = probe.value.match_body
        status_code = probe.value.match_status_codes
      }

      pick_host_name_from_backend_http_settings = probe.value.pick_host_name_from_backend_http_settings
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.redirect_configurations
    content {
      name                 = redirect_configuration.value.name
      redirect_type        = redirect_configuration.value.redirect_type
      target_listener_name = redirect_configuration.value.target_listener_name
      target_url           = redirect_configuration.value.target_url
      include_path         = redirect_configuration.value.include_path
      include_query_string = redirect_configuration.value.include_query_string
    }
  }

  # normal requests
  dynamic "request_routing_rule" {
    for_each = var.basic_request_routing_rules
    content {
      name                       = request_routing_rule.value.name
      rule_type                  = "Basic"
      http_listener_name         = request_routing_rule.value.http_listener_name
      backend_address_pool_name  = request_routing_rule.value.backend_address_pool_name
      backend_http_settings_name = request_routing_rule.value.backend_http_settings_name
    }
  }
  # redirected requests
  dynamic "request_routing_rule" {
    for_each = var.redirect_request_routing_rules
    content {
      name                        = request_routing_rule.value.name
      rule_type                   = "Basic"
      http_listener_name          = request_routing_rule.value.http_listener_name
      redirect_configuration_name = request_routing_rule.value.redirect_configuration_name
    }
  }

  # Path based request routing
  dynamic "request_routing_rule" {
    for_each = var.path_based_request_routing_rules
    content {
      name               = request_routing_rule.value.name
      rule_type          = "PathBasedRouting"
      http_listener_name = request_routing_rule.value.http_listener_name
      url_path_map_name  = request_routing_rule.value.url_path_map_name
    }
  }

  tags = var.tags
}
