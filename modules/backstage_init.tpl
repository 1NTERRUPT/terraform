#!/bin/sh
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install git ansible awscli python-pip -y
sudo -i -u ubuntu git clone https://github.com/1nterrupt/terraform /home/ubuntu/terraform
sudo -i -u ubuntu aws s3 cp s3://1nterrupt-util/terraform.tfvars /home/ubuntu/terraform/
sudo -i -u ubuntu aws s3 cp s3://1nterrupt-util/keys/utilitel-tools.pem /home/ubuntu/.ssh/id_rsa
sudo -i -u ubuntu chmod 700 /home/ubuntu/.ssh/id_rsa
sudo -i -u ubuntu chmod +x /home/ubuntu/terraform/ansible/ec2.py
