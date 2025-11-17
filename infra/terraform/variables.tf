variable "project_name" {
  description = "Name of the project."
}

variable "environment" {
  description = "Deployment environment name."
}

variable "location" {
  description = "Azure region for the deployment."
  default     = "southindia"
}

variable "azure_devops_org_url" {
  description = "URL of the Azure DevOps organization."
  type        = string
}

variable "azure_devops_project" {
  description = "Name of the Azure DevOps project."
  default     = "FinRAGProject"
}

variable "azure_devops_pat" {
  description = "Personal Access Token for Azure DevOps."
  sensitive   = true
}

variable "create_azure_devops_project" {
  description = "Whether to create a new Azure DevOps project."
  type        = bool
  default     = true
}

variable "ado_service_connection_name" {
  description = "Name of the Azure DevOps service connection."
  default     = "FinRAGServiceConnection"
}

variable "ado_environment_name" {
  description = "Name of the Azure DevOps environment."
  default     = "FinRAGEnv"
}

# This allows switching SKUs easily
variable "sku_name" {
  default = "B1"
}

variable "oidc_service_principal_name" {
  type        = string
  description = "The name of the service principal to use for OIDC."
}

