provider "aws" {
  region = "us-west-2"
}

module "oracle" {
  source = "../oracle-deploy/terraform/oracle"
  name = basename(path.cwd)

  eth_count = 1
  boot_count = 1
  feed_count = 1
  feed_lb_count = 0
  bb_count = 0
  relay_count = 1
  ghost_count = 0
  spectre_count = 0

  aws_region = "us-west-2"
  nixos_ami = "ami-081d3bb5fbee0a1ac" # us-west-2
  instance_volume_size = 16
  instance_type = "t2.small"

  ssh_key = file("${abspath(path.root)}/secret/ssh_key.pub")
}

output "rootPath" {
  value = abspath(path.root)
}
output "cloudwatch" {
  value = true
}
output "nixiform" {
  value = [for i,o in module.oracle.nixiform: merge(o,{
    env=basename(path.cwd)
    env_idx=1
  })]
}
