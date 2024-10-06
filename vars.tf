variable "azurerm_linux_virtual_machine_scale_set" {
  type = object({
    vm_instances   = number
    admin_username = string
  })
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "name" {
  description = "Name to apply for all resources in the stack"
  type        = string
}

variable "location" {
  description = "The Azure region"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)

}

variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string

}
