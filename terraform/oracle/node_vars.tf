variable "feed_count" {
  default = 0
  description = "The number of feed nodes to create"
  type = number
}

variable "feed_lb_count" {
  default = 0
  description = "The number of feed lb nodes to create"
  type = number
}

variable "bb_count" {
  default = 0
  description = "The number of feed bb nodes to create"
  type = number
}

variable "relay_count" {
  default = 0
  description = "The number of relay nodes to create"
  type = number
}

variable "eth_count" {
  default = 1
  description = "The number of ethereum nodes to create"
  type = number
}

variable "boot_count" {
  default = 1
  description = "The number of spire bootstrap nodes to create"
  type = number
}

variable "ghost_count" {
  default = 0
  description = "The number of spire bootstrap nodes to create"
  type = number
}

variable "spectre_count" {
  default = 0
  description = "The number of spire bootstrap nodes to create"
  type = number
}
