variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "test123benrg0126900106"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Southeast Asia"
}

variable "env-name" {
  description = "env name"
  type        = string
}
