# /bin/sh
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install git ansible awscli -y
git clone https://github.com/1nterrupt/terraform
aws s3 cp s3://1nterrupt-util/terraform.tfvars terraform/

