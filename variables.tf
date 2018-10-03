# Set the AWS region for the EC2 instances. This value is also
# used for the S3 bucket.

variable "region" 		{ default = "us-east-1" }

# This is the profile name for you AWS credentials in your
# ~/.aws/credentials file. Do not change unless you are using
# something other than "[default]"

variable "profile"		{ default = "default" }

# This is the name of the S3 bucket where the content files are kept.
# Ansible uses this content. There's no need to change this value.

variable "cfg_bucket" 		{ default = "1nterrupt-util" }

# Enter the values for the keys.

# Enter the full path to your AWS pem file.
variable "master_key" 		{ default = "~/.ssh/utilitel-tools.pem" }

# Enter the name of the file name of your AWS key file without the .pem
# extension.
variable "key_name"		{ default = "utilitel-tools" }

# Do not change this value. This is the DNS domain that is used
# for the core EC2 instances.

variable "ctf-domain"		{ default = "events.1nterrupt.com" }

# The team count is for the name of instances of the "game" 
# environment that's created.

variable "team_count"		{ default = 1 }

variable "control"		{ default = "control" }

# Set the size of the EC2 instances here. When you're testing, it's
# best to leave these as t2.micro and then increase the sizes for
# events. The jump box and the scoreboard are used the more than any
# of the other instances.

variable "inst_type_default"	{ default = "t2.micro" }
variable "inst_type_scoreboard"	{ default = "t2.micro" }
variable "inst_type_jumpbox"	{ default = "t2.micro" }

# These are the subnet ranges for the different networks. There is no
# need to change these unless you have a specific reason to do so.

variable "cidrs"		{ default = {
				  "public"    = "10.0.0.0/16"
				  "command"   = "10.17.0.0/16"
				  "corporate" = "172.16.0.0/16"
				  "ops"       = "192.168.0.0/16"
				  "control"   = "10.1.0.0/16"
  				  }
				}
