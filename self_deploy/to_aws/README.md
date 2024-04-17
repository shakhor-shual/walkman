# Walkman installer for AWS:
Before use this installer (create)take your AWS account’s credentials i.e. access_key and 
secret_key. (It is advisable that you create a dedicated set of AWS credentials from the IAM 
console with programmatic access for your Terraform CLI. Make sure you grant least privileged 
based permissions, instead of full admin access. Read AWS cloud documentation fo more)
- This installer designed to use AWS authentication via ENV variables. Setup they first:
- export AWS_ACCESS_KEY_ID=your_aws_access_key
- export AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key 
 
 ### Walkman in-AWS installation:
- clone [repository](https://github.com/shakhor-shual/walkman/tree/main) to your machine 
- on Linux machine you can install Walkman before and use it to run cloud installer
- on all OS-kind machine you can deploy Walkman for in-cloud with Terraform only
- cd to folder: walkman/self_deploy/to_azure 
- if Walkman already installed  locally, deploy installer to cloud via Walkman 
- otherwise, you can deploy Walkman in the cloud using only Terraform (install it before)
- find in installer folder Terraform package sub-folder and cd to it
- modify tfvars.template file accordingly to you requirements and cloud settings
- run: mv tfvars.template terraform.tfvars; terraform init && terraform apply
- connect to deployed VM via SSH for operate with in-cloud Walkman node





