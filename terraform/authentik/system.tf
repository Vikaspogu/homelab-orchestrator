data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}
