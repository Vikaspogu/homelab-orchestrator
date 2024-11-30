locals {
  oauth_apps = [
    "grafana",
    "openshift",
    "freshrss",
    "paperless",
    "pgadmin"
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
      group         = data.authentik_group.admins.id
      icon_url      = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/grafana.png"
      redirect_uri  = "https://grafana.${var.cluster_domain}/login/generic_oauth"
      launch_url    = "https://grafana.${var.cluster_domain}/login/generic_oauth"
    },
    openshift = {
      client_id     = module.onepassword_application["openshift"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["openshift"].fields["CLIENT_SECRET"]
      group         = data.authentik_group.admins.id
      icon_url      = "https://austindewey.com/wp-content/uploads/2018/10/Logotype_RH_OpenShift_StackedLogo_RGB_Black.png"
      redirect_uri  = "https://oauth-openshift.${var.openshift_cluster_domain}/oauth2callback/authentik"
      launch_url    = "https://console-openshift-console.${var.openshift_cluster_domain}/"
    },
    freshrss = {
      client_id     = module.onepassword_application["freshrss"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["freshrss"].fields["CLIENT_SECRET"]
      group         = data.authentik_group.admins.id
      icon_url      = "https://avatars.githubusercontent.com/u/9414285?s=280&v=4"
      redirect_uri  = "https://rss.${var.cluster_domain}:443/i/oidc/"
      launch_url    = "https://rss.${var.cluster_domain}:443/i/oidc/"
    },
    paperless = {
      client_id     = module.onepassword_application["paperless"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["paperless"].fields["CLIENT_SECRET"]
      group         = data.authentik_group.admins.id
      icon_url      = "https://avatars.githubusercontent.com/u/99562962?s=280&v=4"
      redirect_uri  = "https://paperless.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"
      launch_url    = "https://paperless.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"
    },
    pgadmin = {
      client_id     = module.onepassword_application["pgadmin"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["pgadmin"].fields["CLIENT_SECRET"]
      group         = data.authentik_group.admins.id
      icon_url      = "https://www.pgadmin.org/static/docs/pgadmin4-dev/docs/en_US/_build/html/_images/logo-right-128.png"
      redirect_uri  = "https://pgadmin4.${var.cluster_domain}/oauth2/authorize"
      launch_url    = "https://pgadmin4.${var.cluster_domain}/oauth2/authorize"
    }
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
    {
      matching_mode = "strict",
      url           = each.value.redirect_uri,
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
