output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "api_url" {
  value = azurerm_linux_web_app.api.default_hostname
}

output "azure_openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "storage_static_site" {
  value = azurerm_storage_account.static.primary_web_endpoint
}
