/*data "azurerm_public_ip" "myjenkinsvm" {
  name                = "${azurerm_public_ip.myterraformpublicip.name}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
}
*/
output "public_ip_address" {
  value = "${azurerm_public_ip.myjenkinspublicip.ip_address}"
}
