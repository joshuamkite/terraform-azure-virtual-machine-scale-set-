terraform {
  backend "azurerm" {
    # storage_account_name = var.storage_account_name
    container_name       = "tfstate"
    key                  = "terraform-azure-virtual-machine-scale-set/terraform.tfstate"
    resource_group_name  = "tfstate-rg"
    storage_account_name = var.storage_account_name

  }
}
