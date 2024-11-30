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
