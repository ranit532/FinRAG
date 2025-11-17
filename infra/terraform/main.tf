locals {
  stack_name = "${var.project_name}-${var.environment}"
  devops_project_id = var.create_azure_devops_project ? azuredevops_project.project[0].id : data.azuredevops_project.existing[0].id
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.stack_name}-rg"
  location = var.location
}

resource "azurerm_storage_account" "static" {
  name                     = substr(lower("st${replace(local.stack_name, "-", "")}${random_string.suffix.result}"), 0, 24)
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  https_traffic_only_enabled = true

  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }
}

resource "azurerm_log_analytics_workspace" "log" {
  name                = "${local.stack_name}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appi" {
  name                = "${local.stack_name}-appi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log.id
}

resource "azurerm_cognitive_account" "openai" {
  name                          = "${local.stack_name}-aoai"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = "${local.stack_name}-openai"
  public_network_access_enabled = true
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  rai_policy_name      = "Microsoft.Default"

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  scale {
    type     = "Standard"
    capacity = 1
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-ada-002"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  rai_policy_name      = "Microsoft.Default"
  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }
  scale {
    type = "Standard"
    capacity = 1
  }
}

resource "azurerm_service_plan" "asp" {
  name                = "${local.stack_name}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"

  # Free tier - avoids all quota issues
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "api" {
  name                = "${local.stack_name}-api"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"      = "1"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.appi.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appi.connection_string
    "AZURE_OPENAI_ENDPOINT"         = azurerm_cognitive_account.openai.endpoint
    "AZURE_OPENAI_DEPLOYMENT"       = azurerm_cognitive_deployment.gpt4o.name
    "AZURE_OPENAI_EMBEDDING"        = azurerm_cognitive_deployment.embedding.name
  }
}

resource "azurerm_role_assignment" "api_openai_access" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}

resource "azuread_application" "devops_app" {
  display_name = "${local.stack_name}-ado-sp"
}

resource "azuread_service_principal" "devops_sp" {
  client_id = azuread_application.devops_app.client_id
}

resource "azuread_service_principal_password" "devops_sp_secret" {
  service_principal_id = azuread_service_principal.devops_sp.id
  end_date             = timeadd(timestamp(), "8760h") # 1 year
}

resource "azuredevops_project" "project" {
  count             = var.create_azure_devops_project ? 1 : 0
  name              = var.azure_devops_project
  description       = "FinRAG PoC"
  visibility        = "private"
  version_control   = "Git"
  work_item_template = "Agile"
}

data "azuredevops_project" "existing" {
  count = var.create_azure_devops_project ? 0 : 1
  name  = var.azure_devops_project
}

resource "azuredevops_serviceendpoint_azurerm" "service_connection" {
  project_id            = local.devops_project_id
  service_endpoint_name = "${local.stack_name}-service-connection"
  description           = "OIDC-based connection for Terraform & pipelines"
  credentials {
    serviceprincipalid  = azuread_application.devops_app.client_id
    serviceprincipalkey = azuread_service_principal_password.devops_sp_secret.value
  }
  azurerm_spn_tenantid      = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id   = data.azurerm_subscription.current.subscription_id
  azurerm_subscription_name = data.azurerm_subscription.current.display_name
}

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}
