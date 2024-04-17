# Walkman installer for Azure:
Before use this installer you should have (or create&setup) in Azure a 'service 
principal' with 'Contributor' rights, and take authentication credentials for it.
(Read Azure cloud documentation to perform this step)

This installer designed to use Azure authentication via [ENV variables](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure?tabs=bash) 
Setup they first:
- export ARM_SUBSCRIPTION_ID="<azure_subscription_id>"
- export ARM_TENANT_ID="<azure_subscription_tenant_id>"
- export ARM_CLIENT_ID="<service_principal_appid>"
- export ARM_CLIENT_SECRET="<service_principal_password>"


## For Walkman in-Azure installation:
- clone [repository](https://github.com/shakhor-shual/walkman/tree/main) to your machine 
- on Linux machine you can install Walkman before and use it to run cloud installer
- on all OS-kind machine you can deploy Walkman for in-cloud with Terraform only
- cd to folder: walkman/self_deploy/to_azure 
- if Walkman already installed  locally, deploy installer to cloud via Walkman 
(in this case in .meta sub-folder of installer will be automatically generated
artefact 'ssh-to-self-deploy-WALKMAN.sh' for simplify ssh access on deployed 
Walkman-VM, just run it for connect to VM) 
- otherwise, you can deploy Walkman in the cloud using only Terraform (install it before)
- cd to folder: 00_deploy_walkman 
- modify tfvars.template file accordingly to you requirements and cloud settings
- run: mv tfvars.template terraform.tfvars; terraform init && terraform apply
- connect to deployed VM via SSH for operate with in-cloud Walkman node
- setup any clouds access credentials(in any way) on/for this node, to operate Walkman 
for any DevOps tasks in this (and/or in another) cloud(s)






