## OAuth scopes
data "authentik_property_mapping_provider_scope" "oauth2" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

## Custom scope to set email_verified to true
resource "authentik_property_mapping_provider_scope" "email_verified" {
  name       = "email_verified"
  scope_name = "email"
  expression = <<EOF
return {
    "email": request.user.email,
    "email_verified": True
}
EOF
}
