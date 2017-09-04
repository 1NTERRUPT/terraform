variable "vpc_ids" { type = "list" }
variable "subnet_ids" { type = "list" }
variable "internal_cidr_blocks" { type = "list" }
variable "team_count" {}
variable "ami_id" {}
variable "init_script" {}

data "aws_route53_zone" "events" {
  name = "events.1nterrupt.com"
}

resource "aws_security_group" "all_pub" {
    name = "all_pub"
    description = "Allow all internal traffic"
    count = "${var.team_count}"
    vpc_id = "${element(var.vpc_ids,count.index)}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = "${var.internal_cidr_blocks}"
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "tools" {
    name = "tools"
    description = "Allow all inbound rdp"
    count = "${var.team_count}"
    vpc_id = "${element(var.vpc_ids,count.index)}"

    ingress {
        from_port = 0
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "pub-fileserver" {
    ami = "${var.ami_id}"
    instance_type = "t2.micro"
    count = "${var.team_count}"
    subnet_id = "${element(var.subnet_ids,count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_pub.id}"]
    user_data = "${var.init_script}"

    tags {
        Name = "pub-fileserver"
        team = "${count.index}"
    }
}

resource "aws_instance" "tools" {
    ami = "${var.ami_id}"
    instance_type = "t2.medium"
    count = "${var.team_count}"
    subnet_id = "${element(var.subnet_ids,count.index)}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_pub.id}", "${aws_security_group.tools.id}"]
    user_data = "${var.init_script}"

    tags {
        Name = "tools"
        team = "${count.index}"
    }
}

resource "aws_route53_record" "tools_ext" {
  zone_id = "${data.aws_route53_zone.events.zone_id}"
  count = "${var.team_count}"
  name    = "team-${count.index}.${data.aws_route53_zone.events.name}"
  type    = "A"
  ttl     = "10"
  records = ["${element(aws_instance.tools.*.public_ip, count.index)}"]
}
