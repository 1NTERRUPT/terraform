variable "team_count" 	{}
variable "region" 	{}
variable "cidrs" 	{ type = "map" }
variable "cfg_bucket" 	{}

variable "public" 	{ default = "public" }
variable "corporate" 	{ default = "corporate" }
variable "ops" 		{ default = "ops" }
variable "control" 	{ default = "control" }
variable "command"	{ default = "command" }

variable "image14" 	{ default = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"] }
variable "image16" 	{ default = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"] }


data "aws_route53_zone" "events" {
  name 			= "events.1nterrupt.com"
}

provider "aws" {
    region 		= "${var.region}"
}

data "terraform_remote_state" "utilitel_network" {
    backend 		= "s3"
    config {
        bucket 		= "${var.cfg_bucket}"
        key 		= "utilitel/network.tfstate"
        region 		= "${var.region}"
    }
}

# Render a part using a `template_file`
data "template_file" "script" {
  template 		= "${file("${path.module}/init.tpl")}"
}

module "network" {
  source 		= "network"
  cidrs 		= "${var.cidrs}"
  team_count 		= "${var.team_count}"
}

###################
# Set up the images
###################

data "aws_ami" "ubuntu14" {
    most_recent 	= true
    filter {
        name 		= "name"
        values 		= ["${var.image14}"]
    }
    filter {
        name 		= "virtualization-type"
        values 		= ["hvm"]
    }
    owners 		= ["099720109477"] # Canonical
}

data "aws_ami" "ubuntu16" {
    most_recent 	= true
    filter {
        name 		= "name"
        values 		= ["${var.image16}"]
    }
    filter {
        name 		= "virtualization-type"
        values 		= ["hvm"]
    }
    owners 		= ["099720109477"] # Canonical
}


module "public" {
  source 		= "./public"
  team_count 		= "${var.team_count}"
  ami_id 		= "${data.aws_ami.ubuntu16.id}"
  vpc_ids 		= "${module.network.vpc_ids[var.public]}"
  subnet_ids 		= "${module.network.subnet_ids[var.public]}"
  internal_cidr_blocks 	= ["${var.cidrs[var.public]}","${var.cidrs[var.corporate]}","${var.cidrs[var.ops]}","${var.cidrs[var.control]}","${var.cidrs[var.command]}"]
  init_script 		= "${data.template_file.script.rendered}"
  zone_ids  		= ["${module.network.utilitel_zones}","${module.network.fantcpicks_zones}"]
}

############################
# Create the security groups
############################

resource "aws_security_group" "all_corp" {
    name 		= "all_corp"
    description 	= "Allow all inbound traffic"
    count 		= "${var.team_count}"
    vpc_id 		= "${element(module.network.vpc_ids[var.corporate],count.index)}"

    ingress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["${cidrsubnet(var.cidrs[var.public], 8, count.index)}","${cidrsubnet(var.cidrs[var.corporate], 8 , count.index)}","${cidrsubnet(var.cidrs[var.ops], 8 ,count.index)}","${var.cidrs[var.control]}","${cidrsubnet(var.cidrs[var.command], 8, count.index)}"]
    }

    egress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "all_command" {
    name 		= "all_command"
    description 	= "Allow all inbound traffic"
    count 		= "${var.team_count}"
    vpc_id 		= "${element(module.network.vpc_ids[var.command],count.index)}"

    ingress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["${cidrsubnet(var.cidrs[var.public], 8, count.index)}","${cidrsubnet(var.cidrs[var.corporate], 8 , count.index)}","${cidrsubnet(var.cidrs[var.ops], 8 ,count.index)}","${var.cidrs[var.control]}","${cidrsubnet(var.cidrs[var.command], 8, count.index)}"]
    }

    egress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "all_hmi" {
    name 		= "all_hmi"
    description 	= "Allow all inbound ssh traffic"
    count 		= "${var.team_count}"
    vpc_id 		= "${element(module.network.vpc_ids[var.ops],count.index)}"

    ingress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["${cidrsubnet(var.cidrs[var.public], 8, count.index)}","${cidrsubnet(var.cidrs[var.corporate], 8 , count.index)}","${cidrsubnet(var.cidrs[var.ops], 8 ,count.index)}","${var.cidrs[var.control]}","${cidrsubnet(var.cidrs[var.command], 8, count.index)}"]
    }

    egress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["0.0.0.0/0"]
    }
}

######################################
# Create the instances and DNS entries
######################################

resource "aws_instance" "corpfile01" {
    ami 		= "${data.aws_ami.ubuntu16.id}"
    instance_type 	= "t2.medium"
    subnet_id 		= "${element(module.network.subnet_ids[var.corporate],count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_corp.*.id, count.index)}"]
    count 		= "${var.team_count}"
    user_data 		= "${data.template_file.script.rendered}"

    tags {
        Name 		= "corpfile01"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "corpfile01" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(module.network.utilitel_zones,count.index)}"
  name    		= "corpfile01.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.corpfile01.*.private_ip, count.index)}"]
}

resource "aws_instance" "picks" {
    ami 		= "${data.aws_ami.ubuntu16.id}"
    instance_type 	= "t2.medium"
    subnet_id 		= "${element(module.network.subnet_ids[var.command],count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_command.*.id, count.index)}"]
    count 		= "${var.team_count}"
    user_data 		= "${data.template_file.script.rendered}"

    tags {
        Name 		= "picks"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "picks" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(module.network.fantcpicks_zones,count.index)}"
  name    		= "picks.fantcpicks.net"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.picks.*.private_ip, count.index)}"]
}

resource "aws_instance" "wikiserver" {
    ami 		= "${data.aws_ami.ubuntu16.id}"
    instance_type 	= "t2.medium"
    count 		= "${var.team_count}"
    subnet_id 		= "${element(module.network.subnet_ids[var.corporate],count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_corp.*.id, count.index)}"]
    user_data 		= "${data.template_file.script.rendered}"

    tags {
        Name 		= "wikiserver"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "wikiserver" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(module.network.utilitel_zones,count.index)}"
  name    		= "wikiserver.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.wikiserver.*.private_ip, count.index)}"]
}

resource "aws_instance" "corpblog01" {
    ami 		= "${data.aws_ami.ubuntu16.id}"
    instance_type 	= "t2.medium"
    subnet_id 		= "${element(module.network.subnet_ids[var.corporate],count.index)}"
    key_name 		= "utilitel-tools"
    count 		= "${var.team_count}"
    security_groups 	= ["${element(aws_security_group.all_corp.*.id, count.index)}"]
    user_data 		= "${data.template_file.script.rendered}"

    tags {
        Name 		= "corpblog01"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "corpblog01" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(module.network.utilitel_zones,count.index)}"
  name    		= "corpblog01.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.corpblog01.*.private_ip, count.index)}"]
}


resource "aws_instance" "pumpserver" {
    ami 		= "${data.aws_ami.ubuntu14.id}"
    instance_type 	= "t2.medium"
    subnet_id 		= "${element(module.network.subnet_ids[var.ops],count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_hmi.*.id, count.index)}"]
    count 		= "${var.team_count}"
    user_data 		= "${data.template_file.script.rendered}"

    tags {
        Name 		= "pumpserver"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "pumpserver" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(module.network.utilitel_zones,count.index)}"
  name    		= "pumpserver.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.pumpserver.*.private_ip, count.index)}"]
}


resource "aws_instance" "opsfile01" {
    ami 		= "${data.aws_ami.ubuntu16.id}"
    instance_type 	= "t2.medium"
    subnet_id 		= "${element(module.network.subnet_ids[var.ops],count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_hmi.*.id, count.index)}"]
    count 		= "${var.team_count}"
    user_data 		= "${data.template_file.script.rendered}"

    tags {
        Name 		= "opsfile01"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "opsfile01" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(module.network.utilitel_zones,count.index)}"
  name    		= "opsfile01.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.opsfile01.*.private_ip, count.index)}"]
}

####################
# Output the results
####################

output "vpc_ids" { value = "${module.network.vpc_ids}" }

output "internal_cidr_blocks" { value = ["${cidrsubnet(var.cidrs[var.public], 8 ,1)}","${cidrsubnet(var.cidrs[var.corporate], 8 ,1)}","${cidrsubnet(var.cidrs[var.ops], 8 ,1)}","${cidrsubnet(var.cidrs[var.control], 8 ,1)}"] }

output "route_tables" { value = "${module.network.route_tables}" }
