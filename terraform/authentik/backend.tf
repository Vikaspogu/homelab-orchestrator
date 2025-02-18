terraform {
  backend "s3" {
    bucket = "tofu-state"
    key    = "authentik/authentik.tfstate"
    region = "main" # Region validation will be skipped

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
