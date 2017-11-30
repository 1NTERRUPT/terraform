variable "cidrs" 		{ type="map" }
variable "team_count" 		{}

variable "public" 		{ default = "public" }
variable "corporate" 		{ default = "corporate" }
variable "ops" 			{ default = "ops" }
variable "command" 		{ default = "command" }


data "aws_caller_identity" "current" { }

#################
# Create the VPCs
#################

resource "aws_vpc" "pub" {
    cidr_block 			= "${cidrsubnet(var.cidrs[var.public], 8, count.index)}"
    enable_dns_hostnames 	= true
    enable_dns_support   	= true
    count 			= "${var.team_count}"

    tags {
        Name 			= "utilitel_pub_vpc"
        team 			= "${count.index}"
    }
}

resource "aws_vpc" "command" {
    cidr_block			= "${cidrsubnet(var.cidrs[var.command], 8, count.index)}"
    enable_dns_hostnames	= true
    enable_dns_support		= true
    count			= "${var.team_count}"

    tags {
        Name			= "utilitel_command_vpc"
        team			= "${count.index}"
    }
}

resource "aws_vpc" "corp" {
    cidr_block 			= "${cidrsubnet(var.cidrs[var.corporate], 8, count.index)}"
    enable_dns_hostnames 	= true
    enable_dns_support   	= true
    count 			= "${var.team_count}"

    tags {
        Name 			= "utilitel_corp_vpc"
        team 			= "${count.index}"
}
    }

resource "aws_vpc" "hmi" {
    cidr_block 			= "${cidrsubnet(var.cidrs[var.ops], 8, count.index)}"
    enable_dns_hostnames 	= true
    enable_dns_support   	= true
    count 			= "${var.team_count}"

    tags {
        Name 			= "utilitel_hmi_vpc"
        team 			= "${count.index}"
    }
}

##########################
# Set up zones and routing
##########################

resource "aws_route53_zone" "utilitel" {
  name   			= "utilitel.test"
  count 			= "${var.team_count}"
  vpc_id 			= "${element(aws_vpc.pub.*.id,count.index)}"
}

resource "aws_route53_zone_association" "corporate" {
  zone_id 			= "${element(aws_route53_zone.utilitel.*.zone_id,count.index)}"
  count 			= "${var.team_count}"
  vpc_id  			= "${element(aws_vpc.corp.*.id,count.index)}"
}

resource "aws_route53_zone_association" "command" {
  zone_id 			= "${element(aws_route53_zone.utilitel.*.zone_id,count.index)}"
  count 			= "${var.team_count}"
  vpc_id  			= "${element(aws_vpc.command.*.id,count.index)}"
}

resource "aws_route53_zone_association" "hmi" {
  zone_id 			= "${element(aws_route53_zone.utilitel.*.zone_id,count.index)}"
  count 			= "${var.team_count}"
  vpc_id  			= "${element(aws_vpc.hmi.*.id,count.index)}"
}

###########################
# Setup peering connections
###########################

# Pub to the others

resource "aws_vpc_peering_connection" "pub2corp" {
    peer_owner_id 		= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 		= "${element(aws_vpc.corp.*.id,count.index)}"
    vpc_id 			= "${element(aws_vpc.pub.*.id,count.index)}"
    auto_accept 		= true
    count 			= "${var.team_count}"
}

resource "aws_vpc_peering_connection" "pub2hmi" {
    peer_owner_id 		= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 		= "${element(aws_vpc.hmi.*.id,count.index)}"
    vpc_id 			= "${element(aws_vpc.pub.*.id,count.index)}"
    auto_accept 		= true
    count 			= "${var.team_count}"
}

 resource "aws_vpc_peering_connection" "pub2command" {
    peer_owner_id 		= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 		= "${element(aws_vpc.command.*.id,count.index)}"
    vpc_id 			= "${element(aws_vpc.pub.*.id,count.index)}"
    auto_accept 		= true
    count 			= "${var.team_count}"
}

# Command to others

resource "aws_vpc_peering_connection" "command2hmi" {
    peer_owner_id 		= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 		= "${element(aws_vpc.hmi.*.id,count.index)}"
    vpc_id 			= "${element(aws_vpc.command.*.id,count.index)}"
    auto_accept 		= true
    count 			= "${var.team_count}"
}

 resource "aws_vpc_peering_connection" "command2corp" {
    peer_owner_id 		= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 		= "${element(aws_vpc.corp.*.id,count.index)}"
    vpc_id 			= "${element(aws_vpc.command.*.id,count.index)}"
    auto_accept 		= true
    count 			= "${var.team_count}"
}

# Corp to others

resource "aws_vpc_peering_connection" "corp2hmi" {
    peer_owner_id 		= "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id 		= "${element(aws_vpc.hmi.*.id,count.index)}"
    vpc_id 			= "${element(aws_vpc.corp.*.id,count.index)}"
    auto_accept 		= true
    count 			= "${var.team_count}"
}

##########################
# Set up internet gateways
##########################

resource "aws_internet_gateway" "gw_pub" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.pub.*.id, count.index)}"
}

resource "aws_internet_gateway" "gw_corp" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.corp.*.id, count.index)}"
}

resource "aws_internet_gateway" "gw_hmi" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.hmi.*.id, count.index)}"
}

resource "aws_internet_gateway" "gw_command" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.command.*.id, count.index)}"
}

################
# Create subnets
################

resource "aws_subnet" "pub" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.pub.*.id, count.index)}"
    cidr_block 			= "${cidrsubnet(var.cidrs[var.public], 8, count.index)}"
    map_public_ip_on_launch 	= true
    depends_on 			= ["aws_internet_gateway.gw_pub"]
    tags {
        Name 			= "utilitel_pub"
        team 			= "${count.index}"
    }
}

resource "aws_subnet" "command" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.command.*.id, count.index)}"
    cidr_block 			= "${cidrsubnet(var.cidrs[var.command], 8, count.index)}"
    map_public_ip_on_launch 	= true
    depends_on 			= ["aws_internet_gateway.gw_command"]
    tags {
        Name 			= "command"
        team 			= "${count.index}"
    }
}

resource "aws_subnet" "corp" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.corp.*.id, count.index)}"
    cidr_block 			= "${cidrsubnet(var.cidrs[var.corporate], 8, count.index)}"
    map_public_ip_on_launch 	= true
    depends_on 			= ["aws_internet_gateway.gw_corp"]
    tags {
        Name 			= "utilitel_corp"
        team 			= "${count.index}"
    }
}

resource "aws_subnet" "hmi" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.hmi.*.id, count.index)}"
    cidr_block 			= "${cidrsubnet(var.cidrs[var.ops], 8, count.index)}"
    map_public_ip_on_launch 	= true
    depends_on 			= ["aws_internet_gateway.gw_hmi"]
    tags {
        Name 			= "utilitel_hmi"
        team 			= "${count.index}"
    }
}

#########################
# Routes and route tables
#########################

# Public routing

resource "aws_route_table" "pub" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.pub.*.id, count.index)}"
}

resource "aws_route" "pub2hmi" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.pub.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.ops]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.pub2hmi.*.id, count.index)}"
}

resource "aws_route" "pub2corp" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.pub.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.corporate]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.pub2corp.*.id, count.index)}"
}

resource "aws_route" "pub2command" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.pub.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.command]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.pub2command.*.id, count.index)}"
}

resource "aws_route" "pub2internet" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.pub.*.id, count.index)}"
    destination_cidr_block 	= "0.0.0.0/0"
    gateway_id 			= "${element(aws_internet_gateway.gw_pub.*.id, count.index)}"
}

resource "aws_route_table_association" "pub" {
    count 			= "${var.team_count}"
    subnet_id 			= "${element(aws_subnet.pub.*.id, count.index)}"
    route_table_id 		= "${element(aws_route_table.pub.*.id, count.index)}"
}

# Command routing

resource "aws_route_table" "command" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.command.*.id, count.index)}"
}

resource "aws_route" "command2hmi" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.command.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.ops]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.command2hmi.*.id, count.index)}"
}

resource "aws_route" "command2corp" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.command.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.corporate]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.command2corp.*.id, count.index)}"
}

resource "aws_route" "command2pub" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.command.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.public]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.pub2command.*.id, count.index)}"
}

resource "aws_route" "command2internet" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.command.*.id, count.index)}"
    destination_cidr_block 	= "0.0.0.0/0"
    gateway_id 			= "${element(aws_internet_gateway.gw_command.*.id, count.index)}"
}

resource "aws_route_table_association" "command" {
    count 			= "${var.team_count}"
    subnet_id 			= "${element(aws_subnet.command.*.id, count.index)}"
    route_table_id 		= "${element(aws_route_table.command.*.id, count.index)}"
}

# Corporate routing

resource "aws_route_table" "corp" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.corp.*.id, count.index)}"
}

resource "aws_route" "corp2pub" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.corp.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.public]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.pub2corp.*.id, count.index)}"
}

resource "aws_route" "corp2command" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.corp.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.command]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.command2corp.*.id, count.index)}"
}

resource "aws_route" "corp2internet" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.corp.*.id, count.index)}"
    destination_cidr_block 	= "0.0.0.0/0"
    gateway_id 			= "${element(aws_internet_gateway.gw_corp.*.id, count.index)}"
}

resource "aws_route_table_association" "corp" {
    count 			= "${var.team_count}"
    subnet_id 			= "${element(aws_subnet.corp.*.id, count.index)}"
    route_table_id 		= "${element(aws_route_table.corp.*.id, count.index)}"
}

# Ops routing

resource "aws_route_table" "hmi" {
    count 			= "${var.team_count}"
    vpc_id 			= "${element(aws_vpc.hmi.*.id, count.index)}"
}

resource "aws_route" "hmi2pub" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.hmi.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.public]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.pub2hmi.*.id, count.index)}"
}

resource "aws_route" "hmi2command" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.hmi.*.id, count.index)}"
    destination_cidr_block 	= "${var.cidrs[var.command]}"
    vpc_peering_connection_id 	= "${element(aws_vpc_peering_connection.command2hmi.*.id, count.index)}"
}

resource "aws_route" "hmi2corporate" {
    count			= "${var.team_count}"
    route_table_id		= "${element(aws_route_table.hmi.*.id, count.index)}"
    destination_cidr_block	= "${var.cidrs[var.corporate]}"
    vpc_peering_connection_id	= "${element(aws_vpc_peering_connection.corp2hmi.*.id, count.index)}"
}

resource "aws_route" "hmi2internet" {
    count 			= "${var.team_count}"
    route_table_id 		= "${element(aws_route_table.hmi.*.id, count.index)}"
    destination_cidr_block 	= "0.0.0.0/0"
    gateway_id 			= "${element(aws_internet_gateway.gw_hmi.*.id, count.index)}"
}

resource "aws_route_table_association" "hmi" {
    count 			= "${var.team_count}"
    subnet_id 			= "${element(aws_subnet.hmi.*.id, count.index)}"
    route_table_id 		= "${element(aws_route_table.hmi.*.id, count.index)}"
}

################
# Output results
################

output "vpc_ids" {
  value = {
    "public" = ["${aws_vpc.pub.*.id}"]
    "corporate" = ["${aws_vpc.corp.*.id}"]
    "ops" = ["${aws_vpc.hmi.*.id}"]
    "command" = ["${aws_vpc.command.*.id}"]
  }
}

output "subnet_ids" {
  value = {
    "public" = ["${aws_subnet.pub.*.id}"]
    "corporate" = ["${aws_subnet.corp.*.id}"]
    "ops" = ["${aws_subnet.hmi.*.id}"]
    "command" = ["${aws_subnet.command.*.id}"]
  }
}

output "route_tables" {
  value = {
    "public" = ["${aws_route_table.pub.*.id}"]
    "corporate" = ["${aws_route_table.corp.*.id}"]
    "ops" = ["${aws_route_table.hmi.*.id}"]
    "command" = ["${aws_route_table.command.*.id}"]
  }
}

output "utilitel_zones" { value = ["${aws_route53_zone.utilitel.*.zone_id}"] }
