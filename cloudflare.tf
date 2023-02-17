resource "cloudflare_access_application" "onepassword" {
  account_id                = var.cloudflare_account_id
  name                      = "Onepassword Connect"
  domain                    = "op.lealearnstocode.com"
  type                      = "self_hosted"
  session_duration          = "15m"
  auto_redirect_to_identity = false
  logo_url                  = "https://1password.com/img/redesign/press/logo.c757be5591a513da9c768f8b80829318.svg"
}

resource "cloudflare_access_policy" "onepassword" {
  account_id                     = var.cloudflare_account_id
  application_id                 = cloudflare_access_application.onepassword.id
  decision                       = "allow"
  name                           = "Onepassword-Connect"
  precedence                     = 1
  purpose_justification_prompt   = "Why are you accessing this?"
  purpose_justification_required = true

  include {
    any_valid_service_token = true
    email = [ "leafbot@proton.me" ]
  }
}

resource "random_password" "tunnel_secret" {
  length = 32
}

resource "cloudflare_tunnel" "onepassword" {
  account_id = var.cloudflare_account_id
  name       = "onepassword-connect"
  secret     = base64encode(random_password.tunnel_secret.result)
}
