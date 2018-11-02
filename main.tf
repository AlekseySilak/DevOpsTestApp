# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "${var.auth["subscription_id"]}"
    client_id       = "${var.auth["client_id"]}"
    client_secret   = "${var.auth["client_secret"]}"
    tenant_id       = "${var.auth["tenant_id"]}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myjenkinsgroup" {
    name     = "JenkinsResourceGroup"
    location = "eastus"

    tags {
        environment = "DevOpsTestApp"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myjenkinsnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.myjenkinsgroup.name}"

    tags {
        environment = "DevOpsTestApp"
    }
}

# Create subnet
resource "azurerm_subnet" "myjenkinssubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.myjenkinsgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.myjenkinsnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myjenkinspublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.myjenkinsgroup.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "DevOpsTestApp"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myjenkinsnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.myjenkinsgroup.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Jenkins"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "NODE.js"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "1337"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "DevOpsTestApp"
    }
}

# Create network interface
resource "azurerm_network_interface" "myjenkinsnic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.myjenkinsgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.myjenkinsnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.myjenkinssubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myjenkinspublicip.id}"
    }

    tags {
        environment = "DevOpsTestApp"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.myjenkinsgroup.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.myjenkinsgroup.name}"
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "DevOpsTestApp"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myjenkinsvm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.myjenkinsgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.myjenkinsnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm"
        admin_username = "azureuser"
        custom_data = "${file("cloud-init-jenkins.txt")}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${file("~/.ssh/id_rsa.pub")}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "DevOpsTestApp"
    }

}
