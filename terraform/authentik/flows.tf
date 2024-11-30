## Authentication flow
data "authentik_flow" "default-authentication-flow" {
  slug = "default-authentication-flow"
}

## Invalidation flow
data "authentik_flow" "default-provider-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_flow" "invalidation" {
  name               = "invalidation-flow"
  title              = "Invalidation Flow"
  slug               = "invalidation-flow"
  policy_engine_mode = "any"
  designation        = "invalidation"
  denied_action      = "continue"
  # background         = "https://placeholder.jpeg"
}

## Authorization flow
resource "authentik_flow" "provider-authorization-implicit-consent" {
  name               = "Authorize Application"
  title              = "Redirecting to %(app)s"
  slug               = "provider-authorization-implicit-consent"
  policy_engine_mode = "any"
  denied_action      = "message_continue"
  designation        = "authorization"
  # background         = "https://placeholder.jpeg"
}
