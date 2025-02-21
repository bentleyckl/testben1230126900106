variable "env_name" {
  description = "Please Enter Environment Name"
  type        = string
}

# Variable for the resource group name
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "test123benrg0126900106"
}

# Variable for the Azure region
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Southeast Asia"
}