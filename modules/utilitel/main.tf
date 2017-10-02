variable "team_count" {}
variable "region" {}
variable "cidrs" { type="map" }
variable "cfg_bucket" {}

variable "public" { default = "public" }
variable "corporate" { default = "corporate" }
variable "ops" { default = "ops" }
variable "control" { default = "control" }

data "aws_route53_zone" "events" {
  name = "events.1nterrupt.com"
}

provider "aws" {
    region = "${var.region}"
}

data "terraform_remote_state" "utilitel_network" {
    backend = "s3"
    config {
        bucket = "${var.cfg_bucket}"
        key = "utilitel/network.tfstate"
        region = "${var.region}"
    }
}

# Render a part using a `template_file`
data "template_file" "script" {
  template = "${file("${path.module}/init.tpl")}"
}

module "network" {
  source = "network"
  cidrs = "${var.cidrs}"
  team_count = "${var.team_count}"
}

data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"] # Canonical
}

data "aws_ami" "ubuntu16" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"] # Canonical
}


module "public" {
  source = "./public"
  team_count = "${var.team_count}"
  ami_id = "${data.aws_ami.ubuntu16.id}"
  vpc_ids = "${module.network.vpc_ids[var.public]}"
  subnet_ids = "${module.network.subnet_ids[var.public]}"
  internal_cidr_blocks = ["${cidrsubnet(var.cidrs[var.public], 8 ,1)}","${cidrsubnet(var.cidrs[var.corporate], 8 ,1)}","${cidrsubnet(var.cidrs[var.ops], 8 ,1)}","${cidrsubnet(var.cidrs[var.control], 8 ,1)}"]
  init_script = "${data.template_file.script.rendered}"
  zone_ids  = "${module.network.utilitel_zones}"
}

resource "aws_security_group" "all_corp" {
    name = "all_corp"
    description = "Allow all inbound ssh traffic"
    vpc_id = "${element(module.network.vpc_ids[var.corporate],count.index)}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${cidrsubnet(var.cidrs[var.public], 8 ,1)}","${cidrsubnet(var.cidrs[var.corporate], 8 ,1)}","${cidrsubnet(var.cidrs[var.ops], 8 ,1)}","${cidrsubnet(var.cidrs[var.control], 8 ,1)}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "all_hmi" {
    name = "all_hmi"
    description = "Allow all inbound ssh traffic"
    vpc_id = "${element(module.network.vpc_ids[var.ops],count.index)}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${cidrsubnet(var.cidrs[var.public], 8 ,1)}","${cidrsubnet(var.cidrs[var.corporate], 8 ,1)}","${cidrsubnet(var.cidrs[var.ops], 8 ,1)}","${cidrsubnet(var.cidrs[var.control], 8 ,1)}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}



resource "aws_instance" "corpfile01" {
    ami = "${data.aws_ami.ubuntu16.id}"
    instance_type = "t2.micro"
    subnet_id = "${element(module.network.subnet_ids[var.corporate],count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "corpfile01"
        team = "${var.team_count}"
    }
}

resource "aws_instance" "wikiserver" {
    ami = "${data.aws_ami.ubuntu16.id}"
    instance_type = "t2.micro"
    subnet_id = "${element(module.network.subnet_ids[var.corporate],count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "wikiserver"
        team = "${var.team_count}"
    }
}

resource "aws_instance" "corpblog01" {
    ami = "${data.aws_ami.ubuntu16.id}"
    instance_type = "t2.micro"
    subnet_id = "${element(module.network.subnet_ids[var.corporate],count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "corpblog01"
        team = "${var.team_count}"
    }
}

resource "aws_instance" "pumpserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${element(module.network.subnet_ids[var.ops],count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_hmi.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "pumpserver"
        team = "${var.team_count}"
    }
}

resource "aws_instance" "opsfile01" {
    ami = "${data.aws_ami.ubuntu16.id}"
    instance_type = "t2.micro"
    subnet_id = "${element(module.network.subnet_ids[var.ops],count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_hmi.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "opsfile01"
        team = "${var.team_count}"
    }
}


output "vpc_ids" { value = "${module.network.vpc_ids}" }

output "internal_cidr_blocks" { value = ["${cidrsubnet(var.cidrs[var.public], 8 ,1)}","${cidrsubnet(var.cidrs[var.corporate], 8 ,1)}","${cidrsubnet(var.cidrs[var.ops], 8 ,1)}","${cidrsubnet(var.cidrs[var.control], 8 ,1)}"] }

output "route_tables" { value = "${module.network.route_tables}" }
