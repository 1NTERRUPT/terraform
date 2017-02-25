# /bin/sh
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install git ansible awscli python-pip -y
git clone https://github.com/1nterrupt/terraform
aws s3 cp s3://1nterrupt-util/terraform.tfvars terraform/
aws s3 cp s3://1nterrupt-util/keys/utilitel-tools.pem .ssh/id_rsa
chmod 700 ~/.ssh/id_rsa
chmod +x terraform/ansible/ec2.py

