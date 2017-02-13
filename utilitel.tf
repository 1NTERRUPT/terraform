provider "aws" {
    region     = "us-east-1"
}

data "terraform_remote_state" "utilitel_network" {
    backend = "s3"
    config {
        bucket = "1nterrupt-util"
        key = "utilitel/network.tfstate"
        region = "us-east-1"
    }
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "utilitel_vpc"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "corp" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw"]
    tags {
        Name = "utilitel_corp"
    }
}

resource "aws_subnet" "hmi" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.2.0/24"
    tags {
        Name = "utilitel_hmi"
    }
}

resource "aws_route_table" "corp" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
}

resource "aws_route_table_association" "corp" {
    subnet_id = "${aws_subnet.corp.id}"
    route_table_id = "${aws_route_table.corp.id}"
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

resource "aws_instance" "tools" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.corp.id}"
    security_groups = ["${aws_security_group.public_ssh.id}"]
    key_name = "utilitel-tools"
    tags {
        Name = "tools"
    }
}
    
