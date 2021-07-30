
# Azure Application Gateway Terraform Module

**`backend_address_pools`**: List of backend address pools to be created. Each pool can be FQDNs or IP addresses. Each list item should define

  - `name`: Name of backend address pool
  - `ip_addresses`: A list of IP Addresses which should be part of the Backend Address Pool. Set to `null` if using FQDN
  - `fqdns`:  A list of FQDN's which should be part of the Backend Address Pool. Set to `null` if using IP addresses

Example:

```hcl
 backend_address_pools = [
    {
      name         = "fronted-servers"
      ip_addresses = null
      fqdns        = ["frontend.example.com"]
    },
    {
      name         = "backend-servers"
      ip_addresses = [10.0.10.10, 10.0.10.11]
      fqdns        = null
    }
  ]
```
**`http_listeners`**: List of HTTP Listeners to be created. Each list item should define
    - `name` : Name of the listener
    - `ssl_certificate_name`: (Optional) The name of the associated SSL Certificate which should be used for this HTTP Listener.
    - `host_names`: A list of Hostname(s) should be used for this HTTP Listener. It allows special wildcard characters. Setting this value changes Listener Type to 'Multi site'.
    - `require_sni`: Should Server Name Indication be Required?

Example

```hcl
http_listeners = [
  {
    name                 = "frontend"
    ssl_certificate_name = "myapp-com"
    host_names           = ["myapp.com"]
    require_sni          = false
  },
  {
    name                 = "backend"
    ssl_certificate_name = "myapp-com"
    host_names           = ["api.myapp.com"]
    require_sni          = false
  },
]

```

**`backend_http_settings`**: List of backend HTTP settings. Each backend HTTP setting item should have

  - `name`: name of this HTTP setting
  - `path`: The Path which should be used as a prefix for all HTTP requests e.g `/`
  - `port`: The port which should be used for this Backend HTTP Settings Collection. e.g `80` for HTTP or `443` for HTTPS.
  - `protocol`: The Protocol which should be used. Possible values are `Http` and `Https`.
  - `enable_cookie_based_affinity`: Keep a user session on the same server. This will direct subsequent traffic from a user session to the same server for processing.
  - `request_timeout`: Maximum time in seconds to wait for a response which must be between 1 and 86400 seconds.
  - `probe_name`: Name of an associated HTTP probe. Set to `null` if no custom health probe is needed.

Example:

```hcl
 backend_http_settings = [
    {
      name                         = "frontend"
      path                         = "/"
      port                         = 80
      protocol                     = "Http"
      enable_cookie_based_affinity = true
      request_timeout              = 60
      probe_name                   = "frontend-probe"
    },
    {
      name = "API"
      path                         = "/api/"
      port                         = 443
      protocol                     = "Https"
      enable_cookie_based_affinity = true
      is_https                     = true
      request_timeout              = 60
      probe_name                   = "api-health-probe"
    }
  ]
```


**`probes`**:(Optional) List of health probes used to test backend health. Each probe item should have

  - `name`: The name of the probe
  - `path`: The Path used for this probe. e.g `/api/v1/health`
  - `protocol`: The protocol used for this probe. Possible values are `Http` and `Https`
  - `interval`: The Interval between two consecutive probes in seconds. Possible values range from 1 second to a maximum of 86,400 seconds
  - `timeout`: The Timeout used for this Probe, which indicates when a probe becomes unhealthy. Possible values range from 1 second to a maximum of 86,400 seconds.
  - `unhealthy_threshold`: The Unhealthy Threshold for this Probe, which indicates the amount of retries which should be attempted before a node is deemed unhealthy. Possible values are from 1 - 20 seconds.
  - `match_body`: A snippet from the response body which must be present for the probe target to be considered healthy
  - `match_status_codes`: A list of status codes from the request response that indicate a probe target is healthy

Example:

```hcl
probes: [
  {
    name                = "frontend-probe"
    path                = "/"
    protocol            = "http"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_body          = "Welcome"
    match_status_codes  = [200]
  },
  {
    name                = "api-health-probe"
    path                = "/api/v1/health"
    protocol            = "https"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_body          = "healthy"
    match_status_codes  = [200]
  }
]
```

**`redirect_configurations`**:(Optional) List of redirect configurations.

  - `name`: name of the redirect configuration block
  - `redirect_type`: The type of redirect. Possible values are `Permanent`, `Temporary`, `Found` and `SeeOther`
  - `target_listener_name`: The name of the listener to redirect to. Set value to `null` if using `target_url`
  - `target_url`: The Url to redirect the request to. Set value to null if using `target_listener_name`
  - `include_path`: Whether or not to include the path in the redirected Url
  - `include_query_string`: Whether or not to include the query string in the redirected Url

