locals {
  oauth_apps = [
    "grafana",
    "pgadmin",
    "bytestash",
    "reactive-resume",
    "papra",
    "airflow",
    "romm",
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
    bytestash = {
      client_id     = module.onepassword_application["bytestash"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["bytestash"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://raw.githubusercontent.com/jordan-dalby/ByteStash/refs/heads/main/client/public/logo192.png"
      redirect_uris = ["https://bytestash.omv.${var.cluster_domain}/api/auth/oidc/callback"]
      launch_url    = "https://bytestash.omv.${var.cluster_domain}"
    },
    reactive-resume = {
      client_id     = module.onepassword_application["reactive-resume"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["reactive-resume"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://docs.rxresu.me/~gitbook/image?url=https%3A%2F%2F2546827940-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252FZiwItwaQlAySJOpoiYqg%252Ficon%252FAT9ao8E59WpNsnqltfO7%252FProperty%25201%253DLight.png%3Falt%3Dmedia%26token%3D7109dec3-f9ee-468c-91b7-744335795b2a&width=32&dpr=1&quality=100&sign=a184993e&sv=2"
      redirect_uris = ["https://reactive-resume.${var.cluster_domain}/api/auth/openid/callback"]
      launch_url    = "https://reactive-resume.${var.cluster_domain}"
    },
    papra = {
      client_id     = module.onepassword_application["papra"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["papra"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/papra.png"
      redirect_uris = ["https://papra.${var.cluster_domain}/api/auth/oauth2/callback/authentik"]
      launch_url    = "https://papra.${var.cluster_domain}"
    },
    airflow = {
      client_id     = module.onepassword_application["airflow"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["airflow"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://avatars.githubusercontent.com/u/47359?s=48&v=4"
      redirect_uris = ["https://airflow.omv.${var.cluster_domain}/auth/oauth-authorized/authentik"]
      launch_url    = "https://airflow.omv.${var.cluster_domain}"
    },
    romm = {
      client_id     = module.onepassword_application["romm"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["romm"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://avatars.githubusercontent.com/u/47359?s=48&v=4"
      redirect_uris = ["https://romm.${var.cluster_domain}/api/oauth/openid"]
      launch_url    = "https://romm.${var.cluster_domain}"
    },
  }
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each              = local.applications
  name                  = each.key
  client_id             = each.value.client_id
  client_secret         = each.value.client_secret
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = data.authentik_flow.default-authentication-flow.id
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    for uri in each.value.redirect_uris : {
      matching_mode = "strict"
      url           = uri
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
