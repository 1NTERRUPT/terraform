variable "master_key" 	{}
variable "cidrs" 	{ type = "map" }
variable "cfg_bucket" 	{}
variable "region" 	{ default = "us-east-1" }
variable "control" 	{ default = "control" }
variable "team_count"	{ default = "1" }

module "utilitel" {
<<<<<<< HEAD
    source = "./modules/utilitel"
    region = "${var.region}"
    cidrs = "${var.cidrs}"
    cfg_bucket = "${var.cfg_bucket}"
<<<<<<< HEAD
    team_count = 6
=======
    team_count = "${var.team_count}"
>>>>>>> Beginning the C2 additions (the earlier ones didn't seem to show up in the branch)
=======
    source 		= "./modules/utilitel"
    region 		= "${var.region}"
    cidrs 		= "${var.cidrs}"
    cfg_bucket 		= "${var.cfg_bucket}"
    team_count 		= "${var.team_count}"
>>>>>>> Added the [] for the image variables and minor OCD formatting updates
}

module "control" {
    source 		= "./modules/control"
    cidr 		= "${var.cidrs[var.control]}"
    master_key 		= "${var.master_key}"
    region 		= "${var.region}"
    vpc_ids 		= "${module.utilitel.vpc_ids}"
    cidrs 		= "${var.cidrs}"
    internal_cidr_blocks = "${module.utilitel.internal_cidr_blocks}"
    internal_route_tables = "${module.utilitel.route_tables}"
<<<<<<< HEAD
<<<<<<< HEAD
    team_count = 6 
=======
    team_count = "${var.team_count}"
>>>>>>> Beginning the C2 additions (the earlier ones didn't seem to show up in the branch)
=======
    team_count 		= "${var.team_count}"
>>>>>>> Added the [] for the image variables and minor OCD formatting updates
}
