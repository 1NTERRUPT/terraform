variable "master_key" {}
variable "team" {}
variable "pub_cidr" {}
variable "corp_cidr" {}
variable "hmi_cidr" {}
variable "cfg_bucket" {}

module "utilitel_1" {
    source = "./modules/utilitel"
    team   = "${var.team}"
    region = "us-east-1"
    pub_cidr = "${var.pub_cidr}"
    corp_cidr = "${var.corp_cidr}"
    hmi_cidr = "${var.hmi_cidr}"
    cfg_bucket = "${var.cfg_bucket}"
    master_key = "${var.master_key}"
}

output "backstage ip" {
  value = "${module.utilitel_1.backstage_ip}"
}

output "tools ip" {
  value = "${module.utilitel_1.tools_ip}"
}
