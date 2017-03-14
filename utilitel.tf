variable "region" { default = "us-east-1" }
variable "main_cidr" { default = "10.0.0.0/16" }
variable "hmi_cidr" { default = "172.0.0.0/16" }
variable "cfg_bucket" { default = "1nterrupt-util" }
variable "master_key" {}

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
  template = "${file("${path.module}/modules/init.tpl")}"
}

data "aws_caller_identity" "current" { }

resource "aws_vpc" "main" {
    cidr_block = "${var.main_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "utilitel_main_vpc"
    }
}

resource "aws_vpc" "hmi" {
    cidr_block = "${var.hmi_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "utilitel_hmi_vpc"
    }
}

resource "aws_vpc_peering_connection" "corp2hmi" {
    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${aws_vpc.hmi.id}"
    vpc_id = "${aws_vpc.main.id}"
    auto_accept = true
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"
}

resource "aws_internet_gateway" "gw_hmi" {
    vpc_id = "${aws_vpc.hmi.id}"
}

resource "aws_subnet" "corp" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "${cidrsubnet(var.main_cidr, 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw"]
    tags {
        Name = "utilitel_corp"
    }
}

resource "aws_subnet" "hmi" {
    vpc_id = "${aws_vpc.hmi.id}"
    cidr_block = "${cidrsubnet(var.hmi_cidr, 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_hmi"]
    tags {
        Name = "utilitel_hmi"
    }
}

resource "aws_route_table" "corp" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "${aws_vpc.hmi.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.corp2hmi.id}"
    }
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
}

resource "aws_route_table_association" "corp" {
    subnet_id = "${aws_subnet.corp.id}"
    route_table_id = "${aws_route_table.corp.id}"
}
resource "aws_route_table" "hmi" {
    vpc_id = "${aws_vpc.hmi.id}"
    route {
        cidr_block = "${aws_vpc.main.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.corp2hmi.id}"
    }
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw_hmi.id}"
    }
}

resource "aws_route_table_association" "hmi" {
    subnet_id = "${aws_subnet.hmi.id}"
    route_table_id = "${aws_route_table.hmi.id}"
}

data "aws_ami" "ubuntu" {
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

resource "aws_iam_role" "backstage_iam_role" {
    name = "backstage_iam_role"
    assume_role_policy = <<EOF
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
    name = "backstage_instance_profile"
    roles = ["backstage_iam_role"]
}

resource "aws_iam_role_policy" "backstage_iam_role_policy" {
    name = "backstage_iam_role_policy"
    role = "${aws_iam_role.backstage_iam_role.id}"
    policy = <<EOF
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
    name = "allow_ssh"
    description = "Allow all inbound ssh traffic"
    vpc_id = "${aws_vpc.main.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "all_corp" {
    name = "all_corp"
    description = "Allow all inbound ssh traffic"
    vpc_id = "${aws_vpc.main.id}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${aws_subnet.corp.cidr_block}","${aws_subnet.hmi.cidr_block}"]
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
    vpc_id = "${aws_vpc.hmi.id}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${aws_subnet.corp.cidr_block}", "${aws_subnet.hmi.cidr_block}"]
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
    vpc_id = "${aws_vpc.main.id}"

    ingress {
        from_port = 0
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_instance" "backstage" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.corp.id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.public_ssh.id}"]
    user_data = "${data.template_file.script.rendered}"
    iam_instance_profile = "${aws_iam_instance_profile.backstage_instance_profile.id}"

    provisioner "file" {
      source = "ansible"
      destination = "/home/ubuntu"
      connection {
        user = "ubuntu"
        private_key = "${file(var.master_key)}"
        agent = false
      }
    }

    provisioner "remote-exec" {
      inline = [
        "while [ ! -f /tmp/signal ]; do sleep 2; done",
        "chmod u+x /home/ubuntu/ansible/ec2.py" ,
        "sudo pip install --upgrade pip",
        "sudo pip install boto"
      ]

      connection {
        user = "ubuntu"
        private_key = "${file(var.master_key)}"
        agent = false
      }
    }

    tags {
        Name = "backstage"
    }
}

resource "aws_instance" "fileserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.corp.id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "fileserver"
    }
}

resource "aws_instance" "wikiserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.corp.id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "wikiserver"
    }
}

resource "aws_instance" "tools" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.medium"
    subnet_id = "${aws_subnet.corp.id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}", "${aws_security_group.tools.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "tools"
    }
}

resource "aws_instance" "pumpserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.hmi.id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_hmi.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "pumpserver"
    }
}

output "backstage ip" {
  value = "${aws_instance.backstage.public_ip}"
}

output "tools ip" {
  value = "${aws_instance.tools.public_ip}"
}

output "wiki internal ip" {
  value = "${aws_instance.wikiserver.private_ip}"
}

output "file internal ip" {
  value = "${aws_instance.fileserver.private_ip}"
}
