terraform {
  backend "s3" {
    bucket = "tofu-state"
    key    = "authentik/authentik.tfstate"

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = false
    use_path_style              = true
  }
}
