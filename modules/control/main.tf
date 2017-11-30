variable "cidr" 	{}
variable "master_key" 	{}
variable "region" 	{}
variable "vpc_ids" 	{ type = "map"}
variable "cidrs" 	{ type = "map" }
variable "internal_cidr_blocks" { type = "list" }
variable "internal_route_tables" { type = "map" }
variable "team_count" 	{}

variable "public" 	{ default = "public" }
variable "corporate" 	{ default = "corporate" }
variable "ops" 		{ default = "ops" }
variable "command"	{ default = "command" }

provider "aws" {
    region 		= "${var.region}"
}

data "aws_caller_identity" "current" { }

data "aws_route53_zone" "events" {
  name 			= "events.1nterrupt.com"
}

data "aws_ami" "ubuntu16" {
    most_recent 	= true
    filter {
        name 		= "name"
        values 		= ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }
    filter {
        name 		= "virtualization-type"
        values 		= ["hvm"]
    }
    owners 		= ["099720109477"] # Canonical
}

data "template_file" "ec2_ini" {
  template 		= "${file("${path.module}/ec2.ini")}"
}

resource "aws_vpc" "control" {
    cidr_block 		= "${var.cidr}"
    enable_dns_hostnames = true
    tags {
        Name 		= "control_vpc"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id 		= "${aws_vpc.control.id}"
}

resource "aws_subnet" "control" {
    vpc_id 		= "${aws_vpc.control.id}"
    cidr_block 		= "${cidrsubnet(var.cidr, 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on 		= ["aws_internet_gateway.gw"]
    tags {
        Name 		= "control"
    }
}

################################
# Set up the peering connections
################################

resource "aws_vpc_peering_connection" "control2pub" {
    peer_owner_id 	= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 	= "${element(var.vpc_ids[var.public],count.index)}"
    vpc_id 		= "${aws_vpc.control.id}"
    auto_accept 	= true
    count 		= "${var.team_count}"
}

resource "aws_vpc_peering_connection" "control2corp" {
    peer_owner_id 	= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 	= "${element(var.vpc_ids[var.corporate],count.index)}"
    vpc_id 		= "${aws_vpc.control.id}"
    auto_accept 	= true
    count 		= "${var.team_count}"
}

resource "aws_vpc_peering_connection" "control2ops" {
    peer_owner_id 	= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 	= "${element(var.vpc_ids[var.ops],count.index)}"
    vpc_id 		= "${aws_vpc.control.id}"
    auto_accept 	= true
    count 		= "${var.team_count}"
}

resource "aws_vpc_peering_connection" "control2command" {
    peer_owner_id 	= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 	= "${element(var.vpc_ids[var.command],count.index)}"
    vpc_id 		= "${aws_vpc.control.id}"
    auto_accept 	= true
    count 		= "${var.team_count}"
}

#########################
# Set up the route tables
#########################

# Outbound routes from control

resource "aws_route_table" "control" {
    vpc_id 		= "${aws_vpc.control.id}"
}

resource "aws_route" "control2public" {
    count 		= "${var.team_count}"
    route_table_id 	= "${aws_route_table.control.id}"
    destination_cidr_block = "${cidrsubnet(var.cidrs[var.public], 8, count.index)}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2pub.*.id, count.index)}"
}

resource "aws_route" "control2corporate" {
    count 		= "${var.team_count}"
    route_table_id 	= "${aws_route_table.control.id}"
    destination_cidr_block = "${cidrsubnet(var.cidrs[var.corporate], 8, count.index)}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2corp.*.id, count.index)}"
}

resource "aws_route" "control2ops" {
    count 		= "${var.team_count}"
    route_table_id 	= "${aws_route_table.control.id}"
    destination_cidr_block = "${cidrsubnet(var.cidrs[var.ops], 8, count.index)}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2ops.*.id, count.index)}"
}

resource "aws_route" "control2command" {
    count 		= "${var.team_count}"
    route_table_id 	= "${aws_route_table.control.id}"
    destination_cidr_block = "${cidrsubnet(var.cidrs[var.command], 8, count.index)}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2command.*.id, count.index)}"
}

# Inbound routes to control

resource "aws_route" "public2control" {
    count 		= "${var.team_count}"
    route_table_id 	= "${element(var.internal_route_tables[var.public],count.index)}"
    destination_cidr_block = "${var.cidr}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2pub.*.id, count.index)}"
}

resource "aws_route" "corporate2control" {
    count 		= "${var.team_count}"
    route_table_id 	= "${element(var.internal_route_tables[var.corporate],count.index)}"
    destination_cidr_block = "${var.cidr}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2corp.*.id, count.index)}"
}

resource "aws_route" "ops2control" {
    count 		= "${var.team_count}"
    route_table_id 	= "${element(var.internal_route_tables[var.ops],count.index)}"
    destination_cidr_block = "${var.cidr}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2ops.*.id, count.index)}"
}

resource "aws_route" "command2control" {
    count 		= "${var.team_count}"
    route_table_id 	= "${element(var.internal_route_tables[var.command],count.index)}"
    destination_cidr_block = "${var.cidr}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.control2command.*.id, count.index)}"
}

resource "aws_route" "internet" {
    route_table_id 	= "${aws_route_table.control.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id 		= "${aws_internet_gateway.gw.id}"
}

resource "aws_route_table_association" "control" {
    subnet_id 		= "${aws_subnet.control.id}"
    route_table_id 	= "${aws_route_table.control.id}"
}

resource "aws_iam_role" "backstage_iam_role" {
    name 		= "backstage_iam_role"
    assume_role_policy 	= <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "backstage_instance_profile" {
    name 		= "backstage_instance_profile"
    roles 		= ["backstage_iam_role"]
}

resource "aws_iam_role_policy" "backstage_iam_role_policy" {
    name 		= "backstage_iam_role_policy"
    role 		= "${aws_iam_role.backstage_iam_role.id}"
    policy 		= <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:ListBucket"],
        "Resource": ["arn:aws:s3:::1nterrupt-util"]
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:GetObject"
        ],
        "Resource": ["arn:aws:s3:::1nterrupt-util/*"]
      },
      {
        "Effect": "Allow",
        "Action": ["s3:ListBucket"],
        "Resource": ["arn:aws:s3:::1nterrupt-scenario-support"]
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:GetObject"
        ],
        "Resource": ["arn:aws:s3:::1nterrupt-scenario-support/*"]
      },
      {
        "Effect": "Allow",
        "Action": [
          "rds:Describe*",
          "ec2:Describe*",
          "elasticache:*",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource": "*"
      }
    ]
}
EOF
}

resource "aws_security_group" "public_ssh" {
    name 		= "allow_ssh"
    description 	= "Allow external ssh traffic"
    vpc_id 		= "${aws_vpc.control.id}"

    ingress {
        from_port 	= 22
        to_port 	= 22
        protocol 	= "tcp"
        cidr_blocks 	= ["0.0.0.0/0"]
    }

    egress {
        from_port 	= 0
        to_port 	= 0
        protocol 	= "-1"
        cidr_blocks 	= ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "all_internal" {
    name 		= "all_internal"
    description 	= "Allow all internal traffic"
    vpc_id 		= "${aws_vpc.control.id}"

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

data "template_file" "script" {
  template 		= "${file("${path.module}/init.tpl")}"
}

resource "aws_instance" "backstage" {
    ami 		= "${data.aws_ami.ubuntu16.id}"
    instance_type 	= "t2.micro"
    subnet_id 		= "${aws_subnet.control.id}"
    key_name 		= "utilitel-tools"
    security_groups 	= ["${aws_security_group.public_ssh.id}", "${aws_security_group.all_internal.id}"]
    user_data 		= "${data.template_file.script.rendered}"
    iam_instance_profile = "${aws_iam_instance_profile.backstage_instance_profile.id}"

    provisioner "file" {
      source 		= "ansible"
      destination 	= "/home/ubuntu"
      connection {
        user 		= "ubuntu"
        private_key 	= "${file(var.master_key)}"
        agent 		= false
      }
    }

    provisioner "file" {
        content 	= "${data.template_file.ec2_ini.rendered}"
        destination 	= "/home/ubuntu/ansible/ec2.ini"
        connection {
            user 	= "ubuntu"
            private_key = "${file(var.master_key)}"
            agent 	= false
        }
    }


    provisioner "remote-exec" {
      inline = [
        "while [ ! -f /tmp/signal ]; do sleep 2; done",
        "chmod u+x /home/ubuntu/ansible/ec2.py" ,
        "sudo pip install --upgrade pip",
        "sudo pip install boto",
        "sudo pip install boto3"
      ]

      connection {
        user 		= "ubuntu"
        private_key 	= "${file(var.master_key)}"
        agent 		= false
      }
    }

    tags {
        Name 		= "backstage"
    }
}

resource "aws_route53_record" "backstage_ext" {
  zone_id 		= "${data.aws_route53_zone.events.zone_id}"
  name    		= "backstage.${data.aws_route53_zone.events.name}"
  type    		= "A"
  ttl     		= "10"
  records 		= ["${aws_instance.backstage.public_ip}"]
}
