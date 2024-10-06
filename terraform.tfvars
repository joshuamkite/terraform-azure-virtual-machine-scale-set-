resource_group_name = "tfstate-rg"

default_tags = {
  environment = "dev"
  owner       = "joshua"
  project     = "terraform-azure-virtual-machine-scale-set"
}

azurerm_linux_virtual_machine_scale_set = {
  vm_instances   = 2
  admin_username = "adminuser"
}

name     = "terraform-azure-virtual-machine-scale-set"
location = "uksouth"
