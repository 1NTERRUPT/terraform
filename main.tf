variable "master_key" {}
variable "team" {}

module "utilitel_1" {
    source = "./modules/utilitel"
    team   = "${var.team}"
    region = "us-east-1"
    main_cidr = "10.0.0.0/16"
    hmi_cidr = "172.0.0.0/16"
    cfg_bucket = "1nterrupt-util"
    master_key = "${var.master_key}"
}

output "backstage ip" {
  value = "${module.utilitel_1.backstage_ip}"
}

output "tools ip" {
  value = "${module.utilitel_1.tools_ip}"
}

output "wiki internal ip" {
  value = "${module.utilitel_1.wiki_internal_ip}"
}

output "file internal ip" {
  value = "${module.utilitel_1.file_internal_ip}"
}
