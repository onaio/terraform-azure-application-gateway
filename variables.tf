variable "resource_group_name" {
  type = string
}

variable "location" {
  type        = string
  description = "Azure region to create resources in"
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the virtual network to place the resources in"
}

variable "application_gateway_name" {
  type = string
}
variable "frontend_subnet_name" {
  type        = string
  default     = ""
  description = "Name of the frontend subnet to connect the application gateway to"
}

variable "backend_subnet_name" {
  type        = string
  default     = ""
  description = "Name of the backend subnet "
}

variable "application_gateway_sku_name" {
  type        = string
  description = "The Name of the SKU to use for this Application Gateway. Possible values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, and WAF_v2"
}

variable "application_gateway_sku_tier" {
  type        = string
  description = "The Tier of the SKU to use for this Application Gateway. Possible values are Standard, Standard_v2, WAF and WAF_v2"
}

variable "application_gateway_sku_capacity" {
  type        = number
  description = "The Capacity of the SKU to use for this Application Gateway"
}

variable "frontend_http_port" {
  type        = number
  default     = 80
  description = "Frontend port used to listen for HTTP traffic"
}

variable "frontend_https_port" {
  type        = number
  default     = 443
  description = "Frontend port used to listen for HTTPS traffic"

}
variable "backend_address_pools" {
  description = "List of backend address pools."
  type = list(object({
    name         = string
    ip_addresses = list(string)
    fqdns        = list(string)
  }))
}
variable "backend_http_settings" {
  description = "List of backend HTTP settings."
  type = list(object({
    name                         = string
    path                         = string
    port                         = number
    protocol                     = string
    enable_cookie_based_affinity = bool
    request_timeout              = number
    probe_name                   = string
  }))
}

variable "probes" {
  description = "Health probes used to test backend health."
  default     = []
  type = list(object({
    name                = string
    path                = string
    protocol            = string
    interval            = number
    timeout             = number
    unhealthy_threshold = number
    match_body          = string
    match_status_codes  = list(string)
  }))
}

variable "redirect_configurations" {
  description = "A collection of redirect configurations."
  default     = []
  type = list(object({
    name                 = string
    redirect_type        = string
    target_listener_name = string
    target_url           = string
    include_path         = bool
    include_query_string = bool
  }))
}

# Setting a non-null value in host_names converts a listener to 'Multi site'
variable "http_listeners" {
  description = "List of HTTP/HTTPS listeners. HTTPS listeners require an SSL Certificate object."
  type = list(object({
    name                 = string
    ssl_certificate_name = string
    host_names           = list(string)
    require_sni          = bool
  }))
}

variable "basic_request_routing_rules" {
  description = "Request routing rules to be used for listeners."
  type = list(object({
    name                       = string
    http_listener_name         = string
    backend_address_pool_name  = string
    backend_http_settings_name = string
  }))
  default = []
}

variable "redirect_request_routing_rules" {
  description = "Request routing rules to be used for redirect listeners."
  type = list(object({
    name                        = string
    http_listener_name          = string
    redirect_configuration_name = string
  }))
  default = [] # redirect HTTP to HTTPS
}
variable "path_based_request_routing_rules" {
  description = "Path based request routing rules to be used for listeners."
  type = list(object({
    name               = string
    http_listener_name = string
    url_path_map_name  = string
  }))
  default = []
}

variable "tags" {
  type    = object({})
  default = ({})
}

variable "ssl_certificate_name" {
  type        = string
  description = "Name of the SSL certificate to create. This is the name to be used by HTTP listeners"
}

variable "ssl_certificate_key_vault_secret_id" {
  type        = string
  description = "(optional) Resource ID of an Azure key-vault certificate to use. Should be set if ssl_certificate_pfx_data is not set"
}

variable "ssl_certificate_pfx_data" {
  type        = string
  description = "(optional) PFX certificate to use. Should be set if ssl_certificate_key_vault_secret_id is not set"
  default     = null
}

variable "ssl_certificate_pfx_password" {
  type        = string
  description = "(optional) PFX certificate password. Should be set if ssl_certificate_pfx_data is set"
  default     = null
}

variable "public_ip_domain_name_label" {
  type        = string
  description = "(Optional) A domain name label that should reference the public IP"
  default     = null
}
