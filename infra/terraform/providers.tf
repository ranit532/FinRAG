terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 0.10"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

provider "azuredevops" {
  org_service_url       = var.azure_devops_org_url
  personal_access_token = var.azure_devops_pat
}