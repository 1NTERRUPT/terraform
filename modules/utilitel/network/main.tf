variable "cidrs" { type="map" }
variable "team_count" {}

variable "public" { default = "public" }
variable "corporate" { default = "corporate" }
variable "ops" { default = "ops" }


data "aws_caller_identity" "current" { }

resource "aws_vpc" "pub" {
    cidr_block = "${var.cidrs[var.public]}"
    enable_dns_hostnames = true
    count = "${var.team_count}"

    tags {
        Name = "utilitel_pub_vpc"
        team = "${count.index}"
    }
}

resource "aws_vpc" "corp" {
    cidr_block = "${var.cidrs[var.corporate]}"
    enable_dns_hostnames = true
    count = "${var.team_count}"

    tags {
        Name = "utilitel_corp_vpc"
        team = "${count.index}"
    }
}

resource "aws_vpc" "hmi" {
    cidr_block = "${var.cidrs[var.ops]}"
    enable_dns_hostnames = true
    count = "${var.team_count}"

    tags {
        Name = "utilitel_hmi_vpc"
        team = "${count.index}"
    }
}

resource "aws_vpc_peering_connection" "pub2corp" {
    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${element(aws_vpc.corp.*.id,count.index)}"
    vpc_id = "${element(aws_vpc.pub.*.id,count.index)}"
    auto_accept = true
    count = "${var.team_count}"
}

resource "aws_vpc_peering_connection" "pub2hmi" {
    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${element(aws_vpc.hmi.*.id,count.index)}"
    vpc_id = "${element(aws_vpc.pub.*.id,count.index)}"
    auto_accept = true
    count = "${var.team_count}"
}

resource "aws_internet_gateway" "gw_pub" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.pub.*.id, count.index)}"
}

resource "aws_internet_gateway" "gw_corp" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.corp.*.id, count.index)}"
}

resource "aws_internet_gateway" "gw_hmi" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.hmi.*.id, count.index)}"
}

resource "aws_subnet" "pub" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.pub.*.id, count.index)}"
    cidr_block = "${cidrsubnet(var.cidrs[var.public], 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_pub"]
    tags {
        Name = "utilitel_pub"
        team = "${count.index}"
    }
}

resource "aws_subnet" "corp" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.corp.*.id, count.index)}"
    cidr_block = "${cidrsubnet(var.cidrs[var.corporate], 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_corp"]
    tags {
        Name = "utilitel_corp"
        team = "${count.index}"
    }
}

resource "aws_subnet" "hmi" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.hmi.*.id, count.index)}"
    cidr_block = "${cidrsubnet(var.cidrs[var.ops], 8 ,1)}"
    map_public_ip_on_launch = true
    depends_on = ["aws_internet_gateway.gw_hmi"]
    tags {
        Name = "utilitel_hmi"
        team = "${count.index}"
    }
}

resource "aws_route_table" "pub" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.pub.*.id, count.index)}"
}

resource "aws_route" "pub2hmi" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.pub.id}"
    destination_cidr_block = "${var.cidrs[var.ops]}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.pub2hmi.*.id, count.index)}"
}

resource "aws_route" "pub2corp" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.pub.id}"
    destination_cidr_block = "${var.cidrs[var.corporate]}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.pub2corp.*.id, count.index)}"
}

resource "aws_route" "pub2internet" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.pub.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${element(aws_internet_gateway.gw_pub.*.id, count.index)}"
}

resource "aws_route_table_association" "pub" {
    count = "${var.team_count}"
    subnet_id = "${element(aws_subnet.pub.*.id, count.index)}"
    route_table_id = "${element(aws_route_table.pub.*.id, count.index)}"
}

resource "aws_route_table" "corp" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.corp.*.id, count.index)}"
}

resource "aws_route" "corp2pub" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.corp.id}"
    destination_cidr_block = "${var.cidrs[var.public]}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.pub2corp.*.id, count.index)}"
}

resource "aws_route" "corp2internet" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.corp.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${element(aws_internet_gateway.gw_corp.*.id, count.index)}"
}

resource "aws_route_table_association" "corp" {
    count = "${var.team_count}"
    subnet_id = "${element(aws_subnet.corp.*.id, count.index)}"
    route_table_id = "${element(aws_route_table.corp.*.id, count.index)}"
}

resource "aws_route_table" "hmi" {
    count = "${var.team_count}"
    vpc_id = "${element(aws_vpc.hmi.*.id, count.index)}"
}

resource "aws_route" "hmi2pub" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.hmi.id}"
    destination_cidr_block = "${var.cidrs[var.public]}"
    vpc_peering_connection_id = "${element(aws_vpc_peering_connection.pub2hmi.*.id, count.index)}"
}

resource "aws_route" "hmi2internet" {
    count = "${var.team_count}"
    route_table_id = "${aws_route_table.hmi.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${element(aws_internet_gateway.gw_hmi.*.id, count.index)}"
}

resource "aws_route_table_association" "hmi" {
    count = "${var.team_count}"
    subnet_id = "${element(aws_subnet.hmi.*.id, count.index)}"
    route_table_id = "${element(aws_route_table.hmi.*.id, count.index)}"
}

output "vpc_ids" {
  value = {
    "public" = "${aws_vpc.pub.*.id}"
    "corporate" = "${aws_vpc.corp.*.id}"
    "ops" = "${aws_vpc.hmi.*.id}"
  }
}

output "subnet_ids" {
  value = {
    "public" = "${aws_subnet.pub.*.id}"
    "corporate" = "${aws_subnet.corp.*.id}"
    "ops" = "${aws_subnet.hmi.*.id}"
  }
}

output "route_tables" {
  value = {
    "public" = "${aws_route_table.pub.*.id}"
    "corporate" = "${aws_route_table.corp.*.id}"
    "ops" = "${aws_route_table.hmi.*.id}"
  }
}
