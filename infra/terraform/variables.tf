variable "location" {
  description = "Azure region for deployment"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Prefix used for all resources"
  type        = string
  default     = "finrag"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "poc"
}

variable "azure_devops_org_url" {
  description = "Azure DevOps organization URL"
  type        = string
}

variable "azure_devops_project" {
  description = "Azure DevOps project name"
  type        = string
}

variable "azure_devops_pat" {
  description = "Azure DevOps PAT with service connection permissions"
  type        = string
  sensitive   = true
}

variable "oidc_service_principal_name" {
  description = "Display name for the DevOps federated identity"
  type        = string
  default     = "finrag-ado-mi"
}
