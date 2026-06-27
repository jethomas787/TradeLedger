terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tradejournal-dev-canadacentral"
    storage_account_name = "satfledgertfstateboxer9"
    container_name       = "tfstate"
    key                  = "tradejournal-dev.tfstate"
    oidc                 = "true"
  }
}