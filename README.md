 # Description

 This is the terraform config for the utilitel fake utility company

 # First time steps
 1. `aws s3 cp s3://1nterrupt-util/terraform.tfvars .`
    or `cp terraform.tfvars.template terraform.tfvars`
 1. [Install terraform](https://www.terraform.io/intro/getting-started/install.html)

 # To deploy or make changes
 1. Make any changes you'd like
 1. terraform pull
 1. terraform plan
 1. terraform apply

 # To tear down the environment
 1. terraform pull
 1. terraform plan --destroy
 1. terraform destroy

