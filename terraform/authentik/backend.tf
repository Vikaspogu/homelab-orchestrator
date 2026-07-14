terraform {
  backend "kubernetes" {
    namespace     = "tofu-state"
    secret_suffix = "authentik"
  }
}
