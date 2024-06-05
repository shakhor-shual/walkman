# Simple example for AWS:

It creates a network infrastructure and deploys one instance in it with built-in SSH access. 
The 'namespace' variable is used as a prefix when automatically naming created objects 
(as a way to avoid naming conflicts)

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
- cd to folder:  walkman/self_deploy/to_azure 
- if Walkman already installed  locally, deploy installer to cloud via Walkman 
(in this case in .meta sub-folder of installer will be automatically generated
artefact 'ssh-to-cloud-WALKMAN.sh' for simplify ssh access on deployed 
Walkman-VM, just run it for connect to VM) 
- otherwise, you can deploy Walkman in the cloud using only Terraform (install it before)
- cd to folder: 00_deploy_walkman 
- modify tfvars.template file accordingly to you requirements and cloud settings
- run: mv tfvars.template terraform.tfvars; terraform init && terraform apply
- connect to deployed VM via SSH for operate with in-cloud Walkman node
- setup any clouds access credentials(in any way) on/for this node, to operate Walkman 
for any DevOps tasks in this (and/or in another) cloud(s)





