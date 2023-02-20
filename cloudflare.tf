data "cloudflare_zone" "domain" {
  name = "lealearnstocode.com"
}

resource "random_id" "tunnel_secret" {
  byte_length = 64
}

resource "cloudflare_access_group" "onepassword_admins" {
  account_id = var.CLOUDFLARE_ACCOUNT_ID
  name       = "onepassword-admins"
  include {
    email = ["leafbot@proton.me"]
  }
}

resource "cloudflare_tunnel" "onepassword" {
  account_id = var.CLOUDFLARE_ACCOUNT_ID
  name       = "onepassword-connect"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_tunnel_config" "onepassword" {
  account_id = var.CLOUDFLARE_ACCOUNT_ID
  tunnel_id  = cloudflare_tunnel.onepassword.id

  config {
    #    warp_routing {
    #      enabled = true
    #    }
    #    origin_request {
    #      connect_timeout          = "1m0s"
    #      tls_timeout              = "1m0s"
    #      tcp_keep_alive           = "1m0s"
    #      no_happy_eyeballs        = false
    #      keep_alive_connections   = 1024
    #      keep_alive_timeout       = "1m0s"
    #      http_host_header         = "baz"
    #      origin_server_name       = "foobar"
    #      ca_pool                  = "/path/to/unsigned/ca/pool"
    #      no_tls_verify            = false
    #      disable_chunked_encoding = false
    #      bastion_mode             = false
    #      proxy_address            = "10.0.0.1"
    #      proxy_port               = "8123"
    #      proxy_type               = "socks"
    #      ip_rules {
    #        prefix = "/web"
    #        ports  = [80, 443]
    #        allow  = false
    #      }
    #    }
    ingress_rule {
      hostname = "op.${data.cloudflare_zone.domain.name}"
      path     = ""
      service  = "http://localhost:8080"
    }
    ingress_rule {
      hostname = "op.${data.cloudflare_zone.domain.name}"
      path     = "metrics"
      service  = "http://localhost:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "onepassword" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "op"
  value   = "${cloudflare_tunnel.onepassword.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_access_application" "onepassword" {
  account_id                = var.CLOUDFLARE_ACCOUNT_ID
  name                      = "${var.app_env}-onepassword-connect"
  domain                    = "op.${data.cloudflare_zone.domain.name}"
  type                      = "self_hosted"
  session_duration          = "15m"
  auto_redirect_to_identity = false
  app_launcher_visible      = false
  logo_url                  = "https://1password.com/img/redesign/press/logo.c757be5591a513da9c768f8b80829318.svg"
}

#resource "cloudflare_access_policy" "onepassword_bots" {
#  account_id     = var.CLOUDFLARE_ACCOUNT_ID
#  application_id = cloudflare_access_application.onepassword.id
#  decision       = "non_identity"
#  name           = "${var.app_env}-onepassword-connect-service-tokens"
#  precedence     = 0
#
#  include {
#    any_valid_service_token = false
#  }
#}

resource "cloudflare_device_posture_rule" "gateway" {
  account_id = var.CLOUDFLARE_ACCOUNT_ID
  name       = "Require Connection through Gateway"
  type       = "gateway"
}

resource "cloudflare_access_policy" "onepassword_bots" {
  account_id     = var.CLOUDFLARE_ACCOUNT_ID
  application_id = cloudflare_access_application.onepassword.id
  decision       = "allow"
  name           = "${var.app_env}-onepassword-connect-gateway"
  precedence     = 0

  include {
    group = [
      cloudflare_access_group.onepassword_admins.id
    ]
  }
  require {
    device_posture = [
      cloudflare_device_posture_rule.gateway.id
    ]
  }
}
