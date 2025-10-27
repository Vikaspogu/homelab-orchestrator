terraform {
  required_version = ">= 1.0"
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.8.1"
    }

    onepassword = {
      source  = "1Password/onepassword"
      version = "2.2.0"
    }
  }
}

provider "onepassword" {}

module "onepassword_authentik" {
  source = "github.com/joryirving/terraform-1password-item.git?ref=HEAD"
  vault  = "Kubernetes"
  item   = "authentik"
}

provider "authentik" {
  url   = "https://id.${var.cluster_domain}"
  token = module.onepassword_authentik.fields["ADMIN_TOKEN"]
}
