resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = false
}

resource "authentik_policy_binding" "application_policy_binding" {
  for_each = local.applications

  target = authentik_application.application[each.key].uuid
  group  = authentik_group.admins.id
  order  = 0
}

resource "authentik_policy_binding" "agent_farm_portal_admin" {
  target = authentik_application.agent_farm_portal.uuid
  group  = authentik_group.admins.id
  order  = 0
}

resource "authentik_policy_binding" "agent_farm_workspaces_admin" {
  target = authentik_application.agent_farm_workspaces.uuid
  group  = authentik_group.admins.id
  order  = 0
}
