provider "aws" {
  region			= "${var.region}"
  profile			= "${var.profile}"
}

module "utilitel" {
    source 			= "./modules/utilitel"
    region			= "${var.region}"
    ctf-domain			= "${var.ctf-domain}"
    cidrs 			= "${var.cidrs}"
    cfg_bucket 			= "${var.cfg_bucket}"
    team_count 			= "${var.team_count}"
    inst_type_default		= "${var.inst_type_default}"
    inst_type_scoreboard	= "${var.inst_type_scoreboard}"
    inst_type_jumpbox		= "${var.inst_type_jumpbox}"
}

module "control" {
    source 			= "./modules/control"
    region			= "${var.region}"
    cidr 			= "${var.cidrs[var.control]}"
    master_key 			= "${var.master_key}"
    key_name			= "${var.key_name}"
    ctf-domain			= "${var.ctf-domain}"
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
