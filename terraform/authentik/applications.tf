locals {
  oauth_apps = [
    "grafana",
    "pgadmin",
    "reactive-resume",
    "paperless",
    "trek",
    "forge",
  ]
}

# Step 1: Retrieve secrets from 1Password
module "onepassword_application" {
  for_each = toset(local.oauth_apps)
  source   = "github.com/joryirving/terraform-1password-item.git?ref=HEAD"
  vault    = "Kubernetes"
  item     = each.key
}

# Step 2: Parse the secrets using regex to extract client_id and client_secret
locals {
  applications = {
    grafana = {
      client_id     = module.onepassword_application["grafana"].fields["GRAFANA_CLIENT_ID"]
      client_secret = module.onepassword_application["grafana"].fields["GRAFANA_CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/grafana.png"
      redirect_uris = ["https://grafana.${var.cluster_domain}/login/generic_oauth"]
      launch_url    = "https://grafana.${var.cluster_domain}/login/generic_oauth"
    },
    pgadmin = {
      client_id     = module.onepassword_application["pgadmin"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["pgadmin"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://www.pgadmin.org/static/docs/pgadmin4-dev/docs/en_US/_build/html/_images/logo-right-128.png"
      redirect_uris = ["https://pgadmin.${var.cluster_domain}/oauth2/authorize"]
      launch_url    = "https://pgadmin.${var.cluster_domain}/oauth2/authorize"
    },
    reactive-resume = {
      client_id     = module.onepassword_application["reactive-resume"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["reactive-resume"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://docs.rxresu.me/~gitbook/image?url=https%3A%2F%2F2546827940-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252FZiwItwaQlAySJOpoiYqg%252Ficon%252FAT9ao8E59WpNsnqltfO7%252FProperty%25201%253DLight.png%3Falt%3Dmedia%26token%3D7109dec3-f9ee-468c-91b7-744335795b2a&width=32&dpr=1&quality=100&sign=a184993e&sv=2"
      redirect_uris = ["https://reactive-resume.${var.cluster_domain}/api/auth/openid/callback"]
      launch_url    = "https://reactive-resume.${var.cluster_domain}"
    },
    paperless = {
      client_id     = module.onepassword_application["paperless"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["paperless"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/paperless-ngx.png"
      redirect_uris = ["https://paperless.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"]
      launch_url    = "https://paperless.${var.cluster_domain}"
    },
    trek = {
      client_id     = module.onepassword_application["trek"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["trek"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/trek.png"
      redirect_uris = ["https://trek.${var.cluster_domain}/api/auth/oidc/callback"]
      launch_url    = "https://trek.${var.cluster_domain}"
    },
    forge = {
      client_id     = module.onepassword_application["forge"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["forge"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/forge.png"
      redirect_uris = ["https://forge.${var.cluster_domain}/api/forge/auth/callback"]
      launch_url    = "https://forge.${var.cluster_domain}"
    },
  }
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each            = local.applications
  name                = each.key
  client_id           = each.value.client_id
  client_secret       = each.value.client_secret
  authorization_flow  = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow = data.authentik_flow.default-authentication-flow.id
  invalidation_flow   = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.email_verified.id]
  )
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  # Authentik 2026.5 defaults new providers to no allowed grants; set explicitly
  grant_types = ["authorization_code", "refresh_token"]
  allowed_redirect_uris = [
    for uri in each.value.redirect_uris : {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = uri
    }
  ]
}

resource "authentik_application" "application" {
  for_each           = local.applications
  name               = title(each.key)
  slug               = each.key
  protocol_provider  = authentik_provider_oauth2.oauth2[each.key].id
  group              = each.value.group
  open_in_new_tab    = true
  meta_icon          = each.value.icon_url
  meta_launch_url    = each.value.launch_url
  policy_engine_mode = "all"
}

# Public OAuth2 apps (PKCE required, no client_secret)
locals {
  public_oauth_apps = {
    agent-farm = {
      access_token_validity = "minutes=15"
      client_id             = "agent-farm"
      group                 = authentik_group.admins.id
      icon_url              = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/kubernetes.png"
      launch_url            = "https://agent-farm.${var.cluster_domain}"
      redirect_uris = [
        {
          matching_mode     = "strict"
          redirect_uri_type = "authorization"
          url               = "https://agent-farm.${var.cluster_domain}/v1/auth/callback"
        },
        {
          matching_mode     = "regex"
          redirect_uri_type = "authorization"
          url               = "^http://127\\.0\\.0\\.1:[0-9]+/callback$"
        },
      ]
    }
  }
}

resource "authentik_provider_oauth2" "oauth2_public" {
  for_each            = local.public_oauth_apps
  name                = each.key
  client_id           = each.value.client_id
  client_type         = "public"
  authorization_flow  = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow = data.authentik_flow.default-authentication-flow.id
  invalidation_flow   = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.email_verified.id]
  )
  access_token_validity = each.value.access_token_validity
  signing_key           = data.authentik_certificate_key_pair.generated.id
  # Authentik 2026.5 defaults new providers to no allowed grants; set explicitly
  grant_types           = ["authorization_code", "refresh_token"]
  allowed_redirect_uris = each.value.redirect_uris
}

resource "authentik_application" "application_public" {
  for_each           = local.public_oauth_apps
  name               = title(each.key)
  slug               = each.key
  protocol_provider  = authentik_provider_oauth2.oauth2_public[each.key].id
  group              = each.value.group
  open_in_new_tab    = true
  meta_icon          = each.value.icon_url
  meta_launch_url    = each.value.launch_url
  policy_engine_mode = "all"
}

resource "authentik_service_connection_kubernetes" "agent_farm" {
  name  = "Agent Farm Kubernetes"
  local = true
}

resource "authentik_provider_proxy" "agent_farm_portal" {
  name                = "agent-farm-portal"
  authorization_flow  = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow = data.authentik_flow.default-authentication-flow.id
  invalidation_flow   = data.authentik_flow.default-provider-invalidation-flow.id
  external_host       = "https://portal.${var.cluster_domain}"
  internal_host       = "http://agent-farm-web.agent-farm.svc.cluster.local:3000"
  # Static assets are not sensitive; a 302 mid-load breaks JS hydration.
  skip_path_regex = "^/(_next/static|icon.svg|favicon.ico)"
}

resource "authentik_application" "agent_farm_portal" {
  name               = "Agent Farm Portal"
  slug               = "agent-farm-portal"
  protocol_provider  = authentik_provider_proxy.agent_farm_portal.id
  group              = authentik_group.admins.id
  open_in_new_tab    = true
  meta_icon          = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/kubernetes.png"
  meta_launch_url    = "https://portal.${var.cluster_domain}"
  policy_engine_mode = "all"
}

resource "authentik_provider_proxy" "agent_farm_workspaces" {
  name                = "agent-farm-workspaces"
  authorization_flow  = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow = data.authentik_flow.default-authentication-flow.id
  invalidation_flow   = data.authentik_flow.default-provider-invalidation-flow.id
  mode                = "forward_domain"
  # Authentication URL host must be distinct from the portal provider's
  # external_host: the outpost keys proxy routes on it, and sharing the host
  # shadows the portal (404). This host is routed to the outpost via Home-Ops.
  external_host = "https://agent-farm-auth.${var.cluster_domain}"
  cookie_domain = var.cluster_domain
}

resource "authentik_application" "agent_farm_workspaces" {
  name               = "Agent Farm Workspaces"
  slug               = "agent-farm-workspaces"
  protocol_provider  = authentik_provider_proxy.agent_farm_workspaces.id
  group              = authentik_group.admins.id
  open_in_new_tab    = true
  meta_icon          = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/kubernetes.png"
  policy_engine_mode = "all"
}

resource "authentik_outpost" "agent_farm" {
  name               = "Agent Farm"
  service_connection = authentik_service_connection_kubernetes.agent_farm.id
  protocol_providers = [
    authentik_provider_proxy.agent_farm_portal.id,
    authentik_provider_proxy.agent_farm_workspaces.id,
  ]
  config = jsonencode({
    authentik_host       = "https://id.${var.cluster_domain}"
    kubernetes_namespace = "agent-farm"
    # Single replica: proxy sessions are pod-local, and multiple replicas
    # round-robin into 302s / "oauth state does not match the session".
    kubernetes_replicas     = 1
    kubernetes_service_type = "ClusterIP"
  })
}

# Agent Farm CLI: device-code login (approve on any browser-equipped device,
# MFA included) issuing short-lived user tokens for SSH-over-WebSocket.
resource "authentik_flow" "agent_farm_device_code" {
  name           = "Agent Farm device code"
  title          = "Agent Farm device code"
  slug           = "agent-farm-device-code"
  designation    = "stage_configuration"
  authentication = "require_authenticated"
}

resource "authentik_provider_oauth2" "agent_farm_cli" {
  name                = "agent-farm-cli"
  client_id           = "agent-farm-cli"
  client_type         = "public"
  authorization_flow  = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow = data.authentik_flow.default-authentication-flow.id
  invalidation_flow   = data.authentik_flow.default-provider-invalidation-flow.id
  # ponytail: no offline_access mapping (no managed scope exists in 2026.8), so
  # CLI sessions re-run the 10-second device approval when the 1h token lapses.
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.email_verified.id]
  )
  access_token_validity = "hours=1"
  access_code_validity  = "minutes=10"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  grant_types           = ["urn:ietf:params:oauth:grant-type:device_code", "refresh_token"]
  allowed_redirect_uris = []
}

resource "authentik_application" "agent_farm_cli" {
  name               = "Agent Farm CLI"
  slug               = "agent-farm-cli"
  protocol_provider  = authentik_provider_oauth2.agent_farm_cli.id
  group              = authentik_group.admins.id
  policy_engine_mode = "all"
}

# Manage the default brand only to attach the device-code flow; branding fields
# mirror the live values so the import produces no visual change.
resource "authentik_brand" "default" {
  domain              = "authentik-default"
  default             = true
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  flow_authentication = data.authentik_flow.default-authentication-flow.id
  flow_invalidation   = "fff673bc-33b0-4507-81b0-e44af86e5bbf" # live custom invalidation flow
  flow_user_settings  = "cefecbd0-2c02-41ac-a5e2-84588da128f9" # default-user-settings-flow
  flow_device_code    = authentik_flow.agent_farm_device_code.uuid
}
