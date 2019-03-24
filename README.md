 # Description

 This is the terraform config for the utilitel fake utility company

 # First time steps
 1. `aws s3 cp s3://1nterrupt-scenario-support/vars/terraform/regional.tf .`
 1. `aws s3 cp s3://1nterrupt-scenario-support/vars/terraform/variables.tf .`
 1. `aws s3 cp --recursive s3://1nterrupt-scenario-support/vars/ansible/global_vars ansible/global_vars`
 1. [Install terraform](https://www.terraform.io/intro/getting-started/install.html)

 # To deploy or make changes
 1. Make any changes you'd like
 1. terraform plan
 1. terraform apply

 # To tear down the environment
 1. terraform plan --destroy
 1. terraform destroy

 # To configure the environment
 1. log in to the backstage server
 1. cd ansible
 1. ansible-playbook -i ec2.py utilitel.yml
