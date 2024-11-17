variable "azurerm_linux_virtual_machine_scale_set" {
  type = object({
    vm_instances   = number
    admin_username = string
  })
  description = "azurerm_linux_virtual_machine_scale_set username and number of instances"
}

variable "storage_account_name" {
  type        = string
  description = "The name of the storage account"
}

variable "name" {
  description = "Name to apply for all resources in the stack"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string

}

variable "domain_name" {
  description = "domain name to use for our service"
  type        = string
}

variable "permitted_ssh_cidr" {
  description = "The CIDR block to permit SSH access from"
  type        = string
}
