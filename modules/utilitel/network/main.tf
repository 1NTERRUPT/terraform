variable "pub_cidr" {}
variable "corp_cidr" {}
variable "hmi_cidr" {}
variable "team" {}

data "aws_caller_identity" "current" { }

resource "aws_vpc" "pub" {
    cidr_block = "${var.pub_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "utilitel_pub_vpc"
        team = "${var.team}"
    }
}

resource "aws_vpc" "corp" {
    cidr_block = "${var.corp_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "utilitel_corp_vpc"
        team = "${var.team}"
    }
}

resource "aws_vpc" "hmi" {
    cidr_block = "${var.hmi_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "utilitel_hmi_vpc"
        team = "${var.team}"
    }
}

resource "aws_vpc_peering_connection" "pub2corp" {
    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${aws_vpc.corp.id}"
    vpc_id = "${aws_vpc.pub.id}"
    auto_accept = true
}

resource "aws_vpc_peering_connection" "pub2hmi" {
    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${aws_vpc.hmi.id}"
    vpc_id = "${aws_vpc.pub.id}"
    auto_accept = true
}

resource "aws_internet_gateway" "gw_pub" {
    vpc_id = "${aws_vpc.pub.id}"
}

resource "aws_internet_gateway" "gw_corp" {
    vpc_id = "${aws_vpc.corp.id}"
}

resource "aws_internet_gateway" "gw_hmi" {
    vpc_id = "${aws_vpc.hmi.id}"
}

resource "aws_subnet" "pub" {
    vpc_id = "${aws_vpc.pub.id}"
    cidr_block = "${cidrsubnet(var.pub_cidr, 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_pub"]
    tags {
        Name = "utilitel_pub"
        team = "${var.team}"
    }
}

resource "aws_subnet" "corp" {
    vpc_id = "${aws_vpc.corp.id}"
    cidr_block = "${cidrsubnet(var.corp_cidr, 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_corp"]
    tags {
        Name = "utilitel_corp"
        team = "${var.team}"
    }
}

resource "aws_subnet" "hmi" {
    vpc_id = "${aws_vpc.hmi.id}"
    cidr_block = "${cidrsubnet(var.hmi_cidr, 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_hmi"]
    tags {
        Name = "utilitel_hmi"
        team = "${var.team}"
    }
}

resource "aws_route_table" "pub" {
    vpc_id = "${aws_vpc.pub.id}"
    route {
        cidr_block = "${aws_vpc.hmi.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.pub2hmi.id}"
    }
    route {
        cidr_block = "${aws_vpc.corp.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.pub2corp.id}"
    }
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw_pub.id}"
    }
}

resource "aws_route_table_association" "pub" {
    subnet_id = "${aws_subnet.pub.id}"
    route_table_id = "${aws_route_table.pub.id}"
}

resource "aws_route_table" "corp" {
    vpc_id = "${aws_vpc.corp.id}"
    route {
        cidr_block = "${aws_vpc.pub.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.pub2corp.id}"
    }
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw_corp.id}"
    }
}

resource "aws_route_table_association" "corp" {
    subnet_id = "${aws_subnet.corp.id}"
    route_table_id = "${aws_route_table.corp.id}"
}

resource "aws_route_table" "hmi" {
    vpc_id = "${aws_vpc.hmi.id}"
    route {
        cidr_block = "${aws_vpc.pub.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.pub2hmi.id}"
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

output "public_vpc_id" { value = "${aws_vpc.pub.id}" }
output "public_subnet_id" { value = "${aws_subnet.pub.id}" }

output "corp_vpc_id" { value = "${aws_vpc.corp.id}" }
output "corp_subnet_id" { value = "${aws_subnet.corp.id}" }

output "hmi_vpc_id" { value = "${aws_vpc.hmi.id}" }
output "hmi_subnet_id" { value = "${aws_subnet.hmi.id}" }
