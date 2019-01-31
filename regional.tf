# Set the AWS region for the EC2 instances.

variable "region" {
  default = "us-east-1"
}

# This is the profile name for you AWS credentials in your
# ~/.aws/credentials file. Do not change unless you are using
# something other than "[default]"

variable "profile" {
  default = "default"
}

# This is the name of the S3 bucket where the content files are kept.
# Ansible uses this content. There's no need to change this value.

variable "cfg_bucket" {
  default = "1nterrupt-util"
}

# Enter the values for the keys.

# Enter the full path to your AWS pem file.
variable "master_key" {
  default = "~/.ssh/utilitel-tools.pem"
}

# Enter the name of the file name of your AWS key file without the .pem
# extension.
variable "key_name" {
  default = "utilitel-tools"
}

# The team count is for the name of instances of the "game"
# environment that's created.

variable "team_count" {
  default = 1
}
