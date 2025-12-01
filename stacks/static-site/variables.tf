variable "duplo_host" {
  type        = string
  description = "Base URL of the DuploCloud portal"
}

variable "duplo_token" {
  type        = string
  description = "DuploCloud API token"
  sensitive   = true
}
