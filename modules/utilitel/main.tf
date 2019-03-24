variable "region" {}
variable "team_count" {}
variable "key_name" {}
variable "ctf_domain" {}
variable "company_domain" {}
variable "c2_domain" {}

variable "cidrs" {
  type = "map"
}

variable "c2_cidr" {
  default = "c2_cidr"
}

variable "cfg_bucket" {}
variable "inst_type_default" {}
variable "inst_type_scoreboard" {}
variable "inst_type_jumpbox" {}
variable "inst_type_mail" {}
variable "inst_type_breakout" {}

variable "public" {
  default = "public"
}

variable "corporate" {
  default = "corporate"
}

variable "ops" {
  default = "ops"
}

variable "control" {
  default = "control"
}

variable "c2" {
  default = "c2"
}

variable "image14" {
  default = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
}

variable "image16" {
  default = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
}

variable "image18" {
  default = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
}

data "aws_route53_zone" "events" {
  name = "${var.ctf_domain}"
}

resource "aws_route53_zone" "utilitel" {
  name = "${var.company_domain}"
}

resource "aws_route53_zone" "c2" {
  name = "${var.c2_domain}"
}

data "terraform_remote_state" "utilitel_network" {
  backend = "s3"

  config {
    bucket = "${var.cfg_bucket}"
    key    = "utilitel/network.tfstate"
    region = "${var.region}"
  }
}

# Render a part using a `template_file`
data "template_file" "script" {
  template = "${file("${path.module}/init.tpl")}"
}

module "network" {
  source         = "network"
  cidrs          = "${var.cidrs}"
  company_domain = "${var.company_domain}"
  c2_domain      = "${var.c2_domain}"
  team_count     = "${var.team_count}"
}

###################
# Set up the images
###################

data "aws_ami" "ubuntu14" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.image14}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "ubuntu16" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.image16}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "ubuntu18" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.image18}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "public" {
  source               = "./public"
  key_name             = "${var.key_name}"
  ctf_domain           = "${var.ctf_domain}"
  company_domain       = "${var.company_domain}"
  team_count           = "${var.team_count}"
  ami_id_16            = "${data.aws_ami.ubuntu16.id}"
  ami_id_18            = "${data.aws_ami.ubuntu18.id}"
  vpc_ids              = "${module.network.vpc_ids[var.public]}"
  subnet_ids           = "${module.network.subnet_ids[var.public]}"
  internal_cidr_blocks = ["${var.cidrs[var.public]}", "${var.cidrs[var.corporate]}", "${var.cidrs[var.ops]}", "${var.cidrs[var.control]}", "${var.cidrs[var.c2_cidr]}"]
  init_script          = "${data.template_file.script.rendered}"
  zone_ids             = ["${module.network.utilitel_zones}", "${module.network.c2_zones}"]
  inst_type_default    = "${var.inst_type_default}"
  inst_type_jumpbox    = "${var.inst_type_jumpbox}"
  inst_type_breakout   = "${var.inst_type_breakout}"
}

############################
# Create the security groups
############################

resource "aws_security_group" "all_corp" {
  name        = "all_corp"
  description = "Allow all inbound traffic"
  count       = "${var.team_count}"
  vpc_id      = "${element(module.network.vpc_ids[var.corporate],count.index)}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${cidrsubnet(var.cidrs[var.public], 8, count.index)}", "${cidrsubnet(var.cidrs[var.corporate], 8 , count.index)}", "${cidrsubnet(var.cidrs[var.ops], 8 ,count.index)}", "${var.cidrs[var.control]}", "${cidrsubnet(var.cidrs[var.c2_cidr], 8, count.index)}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "all_c2" {
  name        = "all_c2"
  description = "Allow all inbound traffic"
  count       = "${var.team_count}"
  vpc_id      = "${element(module.network.vpc_ids[var.c2],count.index)}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${cidrsubnet(var.cidrs[var.public], 8, count.index)}", "${cidrsubnet(var.cidrs[var.corporate], 8 , count.index)}", "${cidrsubnet(var.cidrs[var.ops], 8 ,count.index)}", "${var.cidrs[var.control]}", "${cidrsubnet(var.cidrs[var.c2_cidr], 8, count.index)}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "all_hmi" {
  name        = "all_hmi"
  description = "Allow all inbound ssh traffic"
  count       = "${var.team_count}"
  vpc_id      = "${element(module.network.vpc_ids[var.ops],count.index)}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${cidrsubnet(var.cidrs[var.public], 8, count.index)}", "${cidrsubnet(var.cidrs[var.corporate], 8 , count.index)}", "${cidrsubnet(var.cidrs[var.ops], 8 ,count.index)}", "${var.cidrs[var.control]}", "${cidrsubnet(var.cidrs[var.c2_cidr], 8, count.index)}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################
# Create the instances and DNS entries
######################################

resource "aws_instance" "corpfile01" {
  ami             = "${data.aws_ami.ubuntu16.id}"
  instance_type   = "${var.inst_type_default}"
  subnet_id       = "${element(module.network.subnet_ids[var.corporate],count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_corp.*.id, count.index)}"]
  count           = "${var.team_count}"
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "corpfile01"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "corpfile01" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  name    = "corpfile01"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.corpfile01.*.private_ip, count.index)}"]
}

resource "aws_instance" "mailserver" {
  ami             = "${data.aws_ami.ubuntu18.id}"
  instance_type   = "${var.inst_type_mail}"
  count           = "${var.team_count}"
  subnet_id       = "${element(module.network.subnet_ids[var.corporate],count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_corp.*.id, count.index)}"]
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "mailserver"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "mailserver" {
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  count   = "${var.team_count}"
  name    = "mailserver"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.mailserver.*.private_ip, count.index)}"]
}

resource "aws_instance" "picks" {
  ami             = "${data.aws_ami.ubuntu16.id}"
  instance_type   = "${var.inst_type_default}"
  subnet_id       = "${element(module.network.subnet_ids[var.c2],count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_c2.*.id, count.index)}"]
  count           = "${var.team_count}"
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "picks"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "picks" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.c2.*.id,count.index)}"
  name    = "picks"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.picks.*.private_ip, count.index)}"]
}

resource "aws_instance" "wikiserver" {
  ami             = "${data.aws_ami.ubuntu16.id}"
  instance_type   = "${var.inst_type_default}"
  count           = "${var.team_count}"
  subnet_id       = "${element(module.network.subnet_ids[var.corporate],count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_corp.*.id, count.index)}"]
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "wikiserver"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "wikiserver" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  name    = "wikiserver"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.wikiserver.*.private_ip, count.index)}"]
}

resource "aws_instance" "blogserver" {
  ami             = "${data.aws_ami.ubuntu16.id}"
  instance_type   = "${var.inst_type_default}"
  subnet_id       = "${element(module.network.subnet_ids[var.corporate],count.index)}"
  key_name        = "${var.key_name}"
  count           = "${var.team_count}"
  security_groups = ["${element(aws_security_group.all_corp.*.id, count.index)}"]
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "blogserver"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "blogserver" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  name    = "blogserver"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.blogserver.*.private_ip, count.index)}"]
}

resource "aws_instance" "pumpserver" {
  ami             = "${data.aws_ami.ubuntu14.id}"
  instance_type   = "${var.inst_type_default}"
  subnet_id       = "${element(module.network.subnet_ids[var.ops],count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_hmi.*.id, count.index)}"]
  count           = "${var.team_count}"
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "pumpserver"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "pumpserver" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  name    = "pumpserver"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.pumpserver.*.private_ip, count.index)}"]
}

resource "aws_instance" "opsfile01" {
  ami             = "${data.aws_ami.ubuntu16.id}"
  instance_type   = "${var.inst_type_default}"
  subnet_id       = "${element(module.network.subnet_ids[var.ops],count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_hmi.*.id, count.index)}"]
  count           = "${var.team_count}"
  user_data       = "${data.template_file.script.rendered}"

  tags {
    Name = "opsfile01"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "opsfile01" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  name    = "opsfile01"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.opsfile01.*.private_ip, count.index)}"]
}

####################
# Output the results
####################

output "vpc_ids" {
  value = "${module.network.vpc_ids}"
}

output "internal_cidr_blocks" {
  value = ["${var.cidrs[var.public]}", "${var.cidrs[var.corporate]}", "${var.cidrs[var.ops]}", "${var.cidrs[var.control]}", "${var.cidrs[var.c2_cidr]}"]
}

output "route_tables" {
  value = "${module.network.route_tables}"
}

output "jumpbox_addresses" {
  value = "${module.public.jumpbox_addresses}"
}
