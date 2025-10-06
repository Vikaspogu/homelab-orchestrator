locals {
  oauth_apps = [
    "grafana",
    "openshift",
    "freshrss",
    "pgadmin",
    "jellyfin",
    "aap-controller",
    "bytestash",
    "reactive-resume",
    "papra",
    "planka",
    "donetick"
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
    freshrss = {
      client_id     = module.onepassword_application["freshrss"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["freshrss"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://avatars.githubusercontent.com/u/9414285?s=280&v=4"
      redirect_uris = ["https://rss.${var.cluster_domain}:443/i/oidc/"]
      launch_url    = "https://rss.${var.cluster_domain}:443/i/oidc/"
    },
    pgadmin = {
      client_id     = module.onepassword_application["pgadmin"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["pgadmin"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://www.pgadmin.org/static/docs/pgadmin4-dev/docs/en_US/_build/html/_images/logo-right-128.png"
      redirect_uris = ["https://pgadmin4.${var.cluster_domain}/oauth2/authorize"]
      launch_url    = "https://pgadmin4.${var.cluster_domain}/oauth2/authorize"
    },
    jellyfin = {
      client_id     = module.onepassword_application["jellyfin"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["jellyfin"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://avatars.githubusercontent.com/u/45698031?s=200&v=4"
      redirect_uris = ["https://jellyfin.${var.cluster_domain}/sso/OID/redirect/authentik"]
      launch_url    = "https://jellyfin.${var.cluster_domain}/sso/OID/start/authentik"
    },
    openshift-vsphere = {
      client_id     = module.onepassword_application["openshift"].fields["CLIENT_ID_VSPHERE"]
      client_secret = module.onepassword_application["openshift"].fields["CLIENT_SECRET_VSPHERE"]
      group         = authentik_group.admins.id
      icon_url      = "https://austindewey.com/wp-content/uploads/2018/10/Logotype_RH_OpenShift_StackedLogo_RGB_Black.png"
      redirect_uris = ["https://oauth-openshift.${var.openshift_vsphere_cluster_domain}/oauth2callback/authentik"]
      launch_url    = "https://console-openshift-console.${var.openshift_vsphere_cluster_domain}/"
    },
    aap-controller = {
      client_id     = module.onepassword_application["aap-controller"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["aap-controller"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://repository-images.githubusercontent.com/177642958/95e2ed0f-953b-4348-b452-54c229136b15"
      redirect_uris = ["https://aap-controller.vikaspogu.internal/api/gateway/social/complete/authentik/"]
      launch_url    = "https://aap-controller.vikaspogu.internal"
    },
    bytestash = {
      client_id     = module.onepassword_application["bytestash"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["bytestash"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://raw.githubusercontent.com/jordan-dalby/ByteStash/refs/heads/main/client/public/logo192.png"
      redirect_uris = ["https://bytestash.omv.v3socp.boo/api/auth/oidc/callback"]
      launch_url    = "https://bytestash.omv.v3socp.boo"
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
    planka = {
      client_id     = module.onepassword_application["planka"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["planka"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/planka.png"
      redirect_uris = ["https://planka.${var.cluster_domain}/oidc-callback"]
      launch_url    = "https://planka.${var.cluster_domain}"
    },
    donetick = {
      client_id     = module.onepassword_application["donetick"].fields["CLIENT_ID"]
      client_secret = module.onepassword_application["donetick"].fields["CLIENT_SECRET"]
      group         = authentik_group.admins.id
      icon_url      = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/donetick.png"
      redirect_uris = ["https://donetick.${var.cluster_domain}/auth/oauth2"]
      launch_url    = "https://donetick.${var.cluster_domain}"
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
