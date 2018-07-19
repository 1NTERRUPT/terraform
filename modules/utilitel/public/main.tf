variable "vpc_ids" 		{ type = "list" }
variable "subnet_ids" 		{ type = "list" }
variable "internal_cidr_blocks" { type = "list" }
variable "team_count" 		{}
variable "ami_id" 		{}
variable "init_script" 		{}
variable "zone_ids" 		{ type = "list" }
variable "inst_type_default"	{}
variable "inst_type_jumpbox"	{}


data "aws_route53_zone" "events" {
  name 			= "events.1nterrupt.com"
}

############################
# Create the security groups
############################

resource "aws_security_group" "all_pub" {
    name 		= "all_pub"
    description 	= "Allow all internal traffic"
    count 		= "${var.team_count}"
    vpc_id 		= "${element(var.vpc_ids,count.index)}"

    ingress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= "${var.internal_cidr_blocks}"
    }

    egress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "tools" {
    name 		= "tools"
    description 	= "Allow all inbound rdp"
    count 		= "${var.team_count}"
    vpc_id 		= "${element(var.vpc_ids,count.index)}"

    ingress {
        from_port 	= 0
        to_port 	= 3389
        protocol 	= "tcp"
        cidr_blocks 	= ["0.0.0.0/0"]
    }
}

######################
# Create the instances
######################

resource "aws_instance" "pubfile01" {
    ami 		= "${var.ami_id}"
    instance_type 	= "${var.inst_type_default}"
    count 		= "${var.team_count}"
    subnet_id 		= "${element(var.subnet_ids,count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_pub.*.id, count.index)}"]
    user_data 		= "${var.init_script}"

    tags {
        Name 		= "pubfile01"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "pubfile01" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(var.zone_ids,count.index)}"
  name    		= "pubfile01.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.pubfile01.*.private_ip, count.index)}"]
}

resource "aws_instance" "tools" {
    ami 		= "${var.ami_id}"
    instance_type 	= "${var.inst_type_jumpbox}"
    count 		= "${var.team_count}"
    subnet_id 		= "${element(var.subnet_ids,count.index)}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${element(aws_security_group.all_pub.*.id, count.index)}", "${element(aws_security_group.tools.*.id, count.index)}"]
    user_data 		= "${var.init_script}"

    tags {
        Name 		= "tools"
        team 		= "${count.index}"
    }
}

resource "aws_route53_record" "tools" {
  count 		= "${var.team_count}"
  zone_id 		= "${element(var.zone_ids,count.index)}"
  name    		= "tools${count.index}.utilitel.test"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.tools.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "tools_ext" {
  zone_id 		= "${data.aws_route53_zone.events.zone_id}"
  count 		= "${var.team_count}"
  name    		= "team-${count.index}.${data.aws_route53_zone.events.name}"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${element(aws_instance.tools.*.public_ip, count.index)}"]
}

output "tools_addresses" { value = "${aws_instance.tools.*.public_ip}" }
