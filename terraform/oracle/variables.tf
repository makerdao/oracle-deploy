variable "aws_region" {
  description = "AWS region to use for CloudWatch dashboard"
  type = string
}

variable "name" {
  description = "Name of module instance"
  type = string
}

variable "eth_rpc_port" {
  description = "Ethereum RPC port"
  type = number
  default = 22008
}

variable "ssb_port" {
  description = "Scuttblebot public port"
  type = number
  default = 33008
}
variable "ssb_port_ws" {
  description = "Scuttblebot public port ws"
  type = number
  default = 33009
}

variable "spire_port" {
  description = "Spire public port"
  type = number
  default = 44008
}

variable "gofer_port" {
  description = "Gofer public port"
  type = number
  default = 44100
}

variable "ssh_key" {
  description = "SSH public key VALUE to use as authorization to instances"
  type = string
}

variable "nixos_ami" {
  description = "A NixOS image or Nixiform compatible image to use for instances"
  type = string
}

variable "instance_type" {
  default = "t2.micro"
  description = "The type of VPS instance to use for nodes"
}

variable "instance_volume_size" {
  default = 16
  description = "Disk space GiB"
}
