provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}

# This is the "game" module where the manufactured environment is
# created. There will be multiple instances of the environment
# corresponding to the number of teams.
module "utilitel" {
  source               = "./modules/utilitel"
  region               = "${var.region}"
  key_name             = "${var.key_name}"
  ctf_domain           = "${var.ctf_domain}"
  company_domain       = "${var.company_domain}"
  c2_domain            = "${var.c2_domain}"
  cidrs                = "${var.cidrs}"
  cfg_bucket           = "${var.cfg_bucket}"
  team_count           = "${var.team_count}"
  inst_type_default    = "${var.inst_type_default}"
  inst_type_scoreboard = "${var.inst_type_scoreboard}"
  inst_type_jumpbox    = "${var.inst_type_jumpbox}"
  inst_type_mail       = "${var.inst_type_mail}"
  inst_type_breakout   = "${var.inst_type_breakout}"
}

# The control module is the central "zone" for core instances such
# as the scoreboard server, backstage server, etc. There are only single
# instances of these regardless of how many teams there are.
module "control" {
  source                   = "./modules/control"
  region                   = "${var.region}"
  cidr                     = "${var.cidrs[var.control]}"
  master_key               = "${var.master_key}"
  key_name                 = "${var.key_name}"
  ctf_domain               = "${var.ctf_domain}"
  company_domain           = "${var.company_domain}"
  c2_domain                = "${var.c2_domain}"
  vpc_ids                  = "${module.utilitel.vpc_ids}"
  cidrs                    = "${var.cidrs}"
  internal_cidr_blocks     = "${module.utilitel.internal_cidr_blocks}"
  internal_route_tables    = "${module.utilitel.route_tables}"
  jumpbox_public_addresses = "${module.utilitel.jumpbox_addresses}"
  team_count               = "${var.team_count}"
  inst_type_default        = "${var.inst_type_default}"
  inst_type_scoreboard     = "${var.inst_type_scoreboard}"
  inst_type_jumpbox        = "${var.inst_type_jumpbox}"
}
