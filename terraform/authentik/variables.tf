variable "cluster_domain" {
  type        = string
  description = "Domain for Authentik"
  default     = ""
}

variable "openshift_cluster_domain" {
  type        = string
  description = "OpenShift cluster Domain for Authentik"
  default     = ""
}
