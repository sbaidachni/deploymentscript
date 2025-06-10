variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "example-resource-group"
}

variable "resource_group_location" {
  description = "The Azure region where the resource group will be created"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "The name of the storage account (must be globally unique and 3-24 lowercase letters and numbers)"
  type        = string
  default     = "examplestorageacct123"
}
