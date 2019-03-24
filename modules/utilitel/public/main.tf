variable "vpc_ids" {
  type = "list"
}

variable "subnet_ids" {
  type = "list"
}

variable "internal_cidr_blocks" {
  type = "list"
}

variable "key_name" {}
variable "team_count" {}
variable "ami_id_16" {}
variable "ami_id_18" {}
variable "init_script" {}

variable "zone_ids" {
  type = "list"
}

variable "inst_type_default" {}
variable "inst_type_jumpbox" {}
variable "inst_type_breakout" {}
variable "ctf_domain" {}
variable "company_domain" {}

data "aws_route53_zone" "events" {
  name = "${var.ctf_domain}"
}

resource "aws_route53_zone" "utilitel" {
  name = "${var.company_domain}"
}

############################
# Create the security groups
############################

resource "aws_security_group" "all_pub" {
  name        = "all_pub"
  description = "Allow all internal traffic"
  count       = "${var.team_count}"
  vpc_id      = "${element(var.vpc_ids,count.index)}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = "${var.internal_cidr_blocks}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jumpbox" {
  name        = "jumpbox"
  description = "Allow all inbound rdp"
  count       = "${var.team_count}"
  vpc_id      = "${element(var.vpc_ids,count.index)}"

  ingress {
    from_port   = 0
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################
# Create the instances
######################

resource "aws_instance" "pubfile01" {
  ami             = "${var.ami_id_18}"
  instance_type   = "${var.inst_type_default}"
  count           = "${var.team_count}"
  subnet_id       = "${element(var.subnet_ids,count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_pub.*.id, count.index)}"]
  user_data       = "${var.init_script}"

  tags {
    Name = "pubfile01"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "pubfile01" {
  count   = "${var.team_count}"
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  name    = "pubfile01"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.pubfile01.*.private_ip, count.index)}"]
}

resource "aws_instance" "jumpbox" {
  ami             = "${var.ami_id_18}"
  instance_type   = "${var.inst_type_jumpbox}"
  count           = "${var.team_count}"
  subnet_id       = "${element(var.subnet_ids,count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_pub.*.id, count.index)}", "${element(aws_security_group.jumpbox.*.id, count.index)}"]
  user_data       = "${var.init_script}"

  tags {
    Name = "jumpbox"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "jumpbox" {
  zone_id = "${data.aws_route53_zone.events.zone_id}"
  count   = "${var.team_count}"
  name    = "${format("team%02d", count.index)}"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.jumpbox.*.public_ip, count.index)}"]
}

resource "aws_instance" "billpay" {
  ami             = "${var.ami_id_18}"
  instance_type   = "${var.inst_type_default}"
  count           = "${var.team_count}"
  subnet_id       = "${element(var.subnet_ids,count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_pub.*.id, count.index)}"]
  user_data       = "${var.init_script}"

  tags {
    Name = "billpay"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "billpay" {
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  count   = "${var.team_count}"
  name    = "${format("team%02d", count.index)}"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.billpay.*.private_ip, count.index)}"]
}

resource "aws_instance" "breakout" {
  ami             = "${var.ami_id_18}"
  instance_type   = "${var.inst_type_breakout}"
  count           = "${var.team_count}"
  subnet_id       = "${element(var.subnet_ids,count.index)}"
  key_name        = "${var.key_name}"
  security_groups = ["${element(aws_security_group.all_pub.*.id, count.index)}"]
  user_data       = "${var.init_script}"

  tags {
    Name = "breakout_server"
    team = "${count.index}"
  }
}

resource "aws_route53_record" "breakout" {
  zone_id = "${element(aws_route53_zone.utilitel.*.id,count.index)}"
  count   = "${var.team_count}"
  name    = "${format("team%02d", count.index)}"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.breakout.*.private_ip, count.index)}"]
}

output "jumpbox_addresses" {
  value = "${aws_instance.jumpbox.*.private_ip}"
}
