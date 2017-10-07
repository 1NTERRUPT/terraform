variable "master_key" {}
variable "cidrs" { type = "map" }
variable "cfg_bucket" {}
variable "region" { default = "us-east-1" }

variable "control" { default = "control" }

module "utilitel" {
    source = "./modules/utilitel"
    region = "${var.region}"
    cidrs = "${var.cidrs}"
    cfg_bucket = "${var.cfg_bucket}"
    team_count = 2
}

module "control" {
    source = "./modules/control"
    cidr = "${var.cidrs[var.control]}"
    master_key = "${var.master_key}"
    region = "${var.region}"
    vpc_ids = "${module.utilitel.vpc_ids}"
    cidrs = "${var.cidrs}"
    internal_cidr_blocks = "${module.utilitel.internal_cidr_blocks}"
    internal_route_tables = "${module.utilitel.route_tables}"
    team_count = 2
}
