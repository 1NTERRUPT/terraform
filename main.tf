variable "master_key" 		{}
variable "cidrs" 		{ type = "map" }
variable "cfg_bucket" 		{}
variable "region" 		{} 
variable "control" 		{ default = "control" }
variable "team_count"		{}
variable "inst_type_default"	{}
variable "inst_type_scoreboard" {}
variable "inst_type_jumpbox"	{}

module "utilitel" {
    source 			= "./modules/utilitel"
    region 			= "${var.region}"
    cidrs 			= "${var.cidrs}"
    cfg_bucket 			= "${var.cfg_bucket}"
    team_count 			= "${var.team_count}"
    inst_type_default		= "${var.inst_type_default}"
    inst_type_scoreboard	= "${var.inst_type_scoreboard}"
    inst_type_jumpbox		= "${var.inst_type_jumpbox}"
}

module "control" {
    source 			= "./modules/control"
    cidr 			= "${var.cidrs[var.control]}"
    master_key 			= "${var.master_key}"
    region 			= "${var.region}"
    vpc_ids 			= "${module.utilitel.vpc_ids}"
    cidrs 			= "${var.cidrs}"
    internal_cidr_blocks 	= "${module.utilitel.internal_cidr_blocks}"
    internal_route_tables 	= "${module.utilitel.route_tables}"
    tools_public_addresses 	= "${module.utilitel.tools_addresses}"
    team_count 			= "${var.team_count}"
    inst_type_default           = "${var.inst_type_default}"
    inst_type_scoreboard        = "${var.inst_type_scoreboard}"
    inst_type_jumpbox           = "${var.inst_type_jumpbox}"
}
