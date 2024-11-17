#  create a resource group for this deployment
resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard_DS1_v2"
  instances           = var.azurerm_linux_virtual_machine_scale_set.vm_instances
  admin_username      = var.azurerm_linux_virtual_machine_scale_set.admin_username
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/azure-20241006.pub")
  }

  # use latest official ubuntu image (we know this will churn version if re-run)
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = filebase64("${path.module}/startup-script.sh")

  network_interface {
    name    = "primary"
    primary = true
    ip_configuration {
      name                                   = "internal"
      subnet_id                              = azurerm_subnet.this.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.this.id]
    }
  }

}

# Define an Azure Load Balancer with a backend address pool, health probe, frontend IP configuration, and load balancer rule:

resource "azurerm_lb" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard" # (required for Front Door)
  frontend_ip_configuration {
    name                 = var.name
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  loadbalancer_id = azurerm_lb.this.id
  name            = var.name
}

# healthcheck for load balancer rule
resource "azurerm_lb_probe" "this" {
  loadbalancer_id     = azurerm_lb.this.id
  name                = var.name
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "this" {
  name                           = var.name
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.this.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.this.id
}

resource "azurerm_public_ip" "this" {
  name                = "${var.name}-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "nat" {
  name                = "${var.name}-nat"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = var.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}


resource "azurerm_network_security_rule" "allow_http_from_frontdoor" {
  name                        = "AllowHTTPFromFrontDoor"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "allow_lb" {
  name                        = "AllowLoadBalancer"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "AllowSSH"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.permitted_ssh_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "allow_outbound" {
  name                        = "AllowOutbound"
  priority                    = 1003
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_nat_gateway" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  subnet_id      = azurerm_subnet.this.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

output "public_ip_address" {
  value       = azurerm_public_ip.this.ip_address
  description = "SSH accessible public IP address"
}
