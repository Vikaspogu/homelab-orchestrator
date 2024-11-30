
data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "admins" {
  name         = "Admins"
  is_superuser = false
}

data "authentik_group" "lookup" {
  for_each = local.applications
  name     = each.value.group
}

resource "authentik_policy_binding" "application_policy_binding" {
  for_each = local.applications

  target = authentik_application.application[each.key].uuid
  group  = data.authentik_group.lookup[each.key].id
  order  = 0
}
