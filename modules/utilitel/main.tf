variable "team" {}
variable "region" {}
variable "pub_cidr" {}
variable "corp_cidr" {}
variable "hmi_cidr" {}
variable "cfg_bucket" {}
variable "master_key" {}

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

data "template_file" "ec2_ini" {
  template = "${file("${path.module}/ec2.ini")}"
  vars {
      team = "${var.team}"
  }
}

module "network" {
  source = "network"
  pub_cidr = "${var.pub_cidr}"
  corp_cidr = "${var.corp_cidr}"
  hmi_cidr = "${var.hmi_cidr}"
  team = "${var.team}"
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
    name = "backstage_iam_role_${var.team}"
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
    name = "backstage_instance_profile_${var.team}"
    roles = ["backstage_iam_role_${var.team}"]
}

resource "aws_iam_role_policy" "backstage_iam_role_policy" {
    name = "backstage_iam_role_policy_${var.team}"
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
    vpc_id = "${module.network.public_vpc_id}"

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

resource "aws_security_group" "all_pub" {
    name = "all_corp"
    description = "Allow all inbound ssh traffic"
    vpc_id = "${module.network.public_vpc_id}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${cidrsubnet(var.pub_cidr, 8 ,1)}","${cidrsubnet(var.corp_cidr, 8 ,1)}","${cidrsubnet(var.hmi_cidr, 8 ,1)}"]
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
    vpc_id = "${module.network.corp_vpc_id}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${cidrsubnet(var.pub_cidr, 8 ,1)}","${cidrsubnet(var.corp_cidr, 8 ,1)}","${cidrsubnet(var.hmi_cidr, 8 ,1)}"]
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
    vpc_id = "${module.network.hmi_vpc_id}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${cidrsubnet(var.pub_cidr, 8 ,1)}","${cidrsubnet(var.corp_cidr, 8 ,1)}","${cidrsubnet(var.hmi_cidr, 8 ,1)}"]
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
    vpc_id = "${module.network.public_vpc_id}"

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
    subnet_id = "${module.network.public_subnet_id}"
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

    provisioner "file" {
        content = "${data.template_file.ec2_ini.rendered}"
        destination = "/home/ubuntu/ansible/ec2.ini"
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
        team = "${var.team}"
    }
}

resource "aws_instance" "pub-fileserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${module.network.public_subnet_id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_pub.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "pub-fileserver"
        team = "${var.team}"
    }
}

resource "aws_instance" "fileserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${module.network.corp_subnet_id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "fileserver"
        team = "${var.team}"
    }
}

resource "aws_instance" "wikiserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${module.network.corp_subnet_id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_corp.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "wikiserver"
        team = "${var.team}"
    }
}

resource "aws_instance" "tools" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.medium"
    subnet_id = "${module.network.public_subnet_id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_pub.id}", "${aws_security_group.tools.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "tools"
        team = "${var.team}"
    }
}

resource "aws_route53_record" "tools_ext" {
  zone_id = "${data.aws_route53_zone.events.zone_id}"
  name    = "${var.team}.${data.aws_route53_zone.events.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.tools.public_ip}"]
}

resource "aws_instance" "pumpserver" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${module.network.hmi_subnet_id}"
    key_name = "utilitel-tools"
    security_groups = ["${aws_security_group.all_hmi.id}"]
    user_data = "${data.template_file.script.rendered}"

    tags {
        Name = "pumpserver"
        team = "${var.team}"
    }
}

output "backstage_ip" {
  value = "${aws_instance.backstage.public_ip}"
}

output "tools_ip" {
  value = "${aws_instance.tools.public_ip}"
}

output "wiki_internal_ip" {
  value = "${aws_instance.wikiserver.private_ip}"
}

output "file_internal_ip" {
  value = "${aws_instance.fileserver.private_ip}"
}
