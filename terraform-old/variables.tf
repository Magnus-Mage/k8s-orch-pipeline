variable "auth_url" {
  description = "OpenStack Authentication URL"
  type        = string
}

variable "user_name" {
  description = "OpenStack Username"
  type        = string
}

variable "password" {
  description = "OpenStack Password"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OpenStack Region"
  type        = string
  default     = "RegionOne"
}




variable "image" {
  default = "Ubuntu-20.04"
}

variable "flavor_http" {
  default = "S.4"
}

variable "volume_http" {
  default = 20
}

variable "worker_count" {
  default = 2
}

