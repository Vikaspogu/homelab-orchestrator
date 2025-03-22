variable "cluster_domain" {
  type        = string
  description = "Domain for Authentik"
  default     = ""
}

variable "openshift_proxmox_cluster_domain" {
  type        = string
  description = "OpenShift cluster Domain for Authentik"
  default     = ""
}

variable "openshift_vsphere_cluster_domain" {
  type        = string
  description = "OpenShift cluster Domain for Authentik"
  default     = ""
}
