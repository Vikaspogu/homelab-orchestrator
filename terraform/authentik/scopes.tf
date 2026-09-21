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

## Injects the agent-farm shared proxy token as an upstream header after
## authentication; the ws-<id> gateway rejects browser traffic without it.
## The value comes from 1Password, never from this repo.
resource "authentik_property_mapping_provider_scope" "agent_farm_proxy_token" {
  name       = "agent-farm-proxy-token"
  scope_name = "agent-farm-proxy-token"
  expression = <<-EOF
    return {
      "ak_proxy": {
        "user_attributes": {
          "additionalHeaders": {
            "X-Agent-Farm-Proxy-Token": "${local.agent_farm_proxy_token}"
          }
        }
      }
    }
  EOF
}

## Injects the agent-farm edge secret on the portal's upstream requests; the
## web tier refuses production requests that lack it. Value from 1Password.
resource "authentik_property_mapping_provider_scope" "agent_farm_edge_secret" {
  name       = "agent-farm-edge-secret"
  scope_name = "agent-farm-edge-secret"
  expression = <<-EOF
    return {
      "ak_proxy": {
        "user_attributes": {
          "additionalHeaders": {
            "X-Agent-Farm-Edge": "${local.agent_farm_edge_secret}"
          }
        }
      }
    }
  EOF
}
