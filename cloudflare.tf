data "cloudflare_zone" "domain" {
  name = "lealearnstocode.com"
}

resource "random_id" "tunnel_secret" {
  byte_length = 64
}

resource "cloudflare_tunnel" "onepassword" {
  account_id = var.CLOUDFLARE_ACCOUNT_ID
  name       = "onepassword-connect"
  secret     = random_id.tunnel_secret.b64_std
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
  logo_url                  = "https://1password.com/img/redesign/press/logo.c757be5591a513da9c768f8b80829318.svg"
}

resource "cloudflare_access_service_token" "onepassword_connect_access" {
  account_id = var.CLOUDFLARE_ACCOUNT_ID
  name       = "${var.app_env}-onepassword-connect-access"
}

resource "cloudflare_access_policy" "onepassword" {
  account_id                     = var.CLOUDFLARE_ACCOUNT_ID
  application_id                 = cloudflare_access_application.onepassword.id
  decision                       = "allow"
  name                           = "${var.app_env}-onepassword-connect"
  precedence                     = 0
  purpose_justification_prompt   = "Why are you accessing this?"
  purpose_justification_required = true

  include {
    service_token = [
      cloudflare_access_service_token.onepassword_connect_access.id
    ]
  }
}

output "cloudflare_service_token_client_id" {
  value = cloudflare_access_service_token.onepassword_connect_access.client_id
}

output "cloudflare_service_token_client_secret" {
  value     = cloudflare_access_service_token.onepassword_connect_access.client_secret
  sensitive = true
}
