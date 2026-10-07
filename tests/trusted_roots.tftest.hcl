mock_provider "azurerm" {
  mock_data "azurerm_subnet" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet" } }
  mock_data "azurerm_resource_group" { defaults = { location = "westeurope", name = "rg" } }
  mock_resource "azurerm_public_ip" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/pip" } }
}

variables {
  location                         = "westeurope"
  resource_group_name              = "rg"
  virtual_network_name             = "vnet"
  application_gateway_name         = "agw"
  frontend_subnet_name             = "snet"
  backend_subnet_name              = "snet"
  application_gateway_sku_name     = "WAF_v2"
  application_gateway_sku_tier     = "WAF_v2"
  application_gateway_sku_capacity = 1
  backend_address_pools            = [{ name = "pool", ip_addresses = [], fqdns = ["backend.example.com"] }]
  http_listeners                   = [{ name = "http", ssl_certificate_name = null, host_names = ["a.example.com"], require_sni = false }]
  basic_request_routing_rules      = [{ name = "rule", http_listener_name = "http", backend_address_pool_name = "pool", backend_http_settings_name = "with-root", priority = 100 }]
  trusted_root_certificates        = [{ name = "backend-root", data = "MIIB" }]
  backend_http_settings = [
    { name = "with-root", path = "/", port = 443, protocol = "Https", enable_cookie_based_affinity = true, request_timeout = 30, probe_name = null, host_name = "a.example.com", pick_host_name_from_backend_address = false, trusted_root_certificate_names = ["backend-root"] },
    { name = "without-root", path = "/", port = 443, protocol = "Https", enable_cookie_based_affinity = true, request_timeout = 30, probe_name = null, host_name = "b.example.com", pick_host_name_from_backend_address = false },
  ]
}

run "roots_reach_the_gateway_and_backend_settings" {
  command = plan
  assert {
    condition     = length(azurerm_application_gateway.main.trusted_root_certificate) == 1 && one(azurerm_application_gateway.main.trusted_root_certificate).name == "backend-root"
    error_message = "trusted root certificate not declared on the gateway"
  }
  assert {
    condition     = [for b in azurerm_application_gateway.main.backend_http_settings : b.trusted_root_certificate_names if b.name == "with-root"][0] == tolist(["backend-root"])
    error_message = "backend setting did not get trusted_root_certificate_names"
  }
  assert {
    condition     = length(coalesce([for b in azurerm_application_gateway.main.backend_http_settings : b.trusted_root_certificate_names if b.name == "without-root"][0], [])) == 0
    error_message = "a backend setting without the field should have no trusted roots"
  }
}

run "no_roots_by_default" {
  command = plan
  variables {
    trusted_root_certificates = []
    backend_http_settings     = [{ name = "with-root", path = "/", port = 80, protocol = "Http", enable_cookie_based_affinity = true, request_timeout = 30, probe_name = null, host_name = "a.example.com", pick_host_name_from_backend_address = false }]
  }
  assert {
    condition     = length(azurerm_application_gateway.main.trusted_root_certificate) == 0
    error_message = "expected no trusted roots"
  }
}

run "root_needs_data_or_key_vault" {
  command = plan
  variables { trusted_root_certificates = [{ name = "empty" }] }
  expect_failures = [var.trusted_root_certificates]
}

run "root_cannot_have_both" {
  command = plan
  variables { trusted_root_certificates = [{ name = "both", data = "MIIB", key_vault_secret_id = "https://kv.vault.azure.net/secrets/x" }] }
  expect_failures = [var.trusted_root_certificates]
}
