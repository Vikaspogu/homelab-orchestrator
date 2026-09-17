## Authentication flow
data "authentik_flow" "default-authentication-flow" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default-authenticator-webauthn-setup" {
  slug = "default-authenticator-webauthn-setup"
}

# Enables conditional WebAuthn passkey autofill on the default identification stage.
resource "authentik_stage_authenticator_validate" "webauthn_passwordless" {
  name                       = "webauthn-passwordless-validation"
  device_classes             = ["webauthn"]
  webauthn_user_verification = "required"
  not_configured_action      = "skip"
}

# Built-in Authentik stage; import before applying.
resource "authentik_stage_identification" "default" {
  name                      = "default-authentication-identification"
  case_insensitive_matching = true
  user_fields               = ["email", "username"]
  webauthn_stage            = authentik_stage_authenticator_validate.webauthn_passwordless.id
}

# Built-in Authentik stage; import before applying. This affects new registrations.
resource "authentik_stage_authenticator_webauthn" "default" {
  name                      = "default-authenticator-webauthn-setup"
  configure_flow            = data.authentik_flow.default-authenticator-webauthn-setup.id
  friendly_name             = "WebAuthn device"
  prevent_duplicate_devices = false
  resident_key_requirement  = "preferred"
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
