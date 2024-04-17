# Walkman installer for Azure:
Before you proceed further, make sure that you have configured access to the cloud 
that you use to work with Terraform (authentication and authorization, rights to 
create objects, availability of APIs to use, etc., etc.). The necessary list of 
settings for Terraform to work is determined by the type of cloud provider used.
Also, read this README to the the end, to better understand your next steps

ForWalkman in-cloud installation:
- Before use this installer you should have (or create&setup) in Azure a 'service 
  principal' with 'Contributor' rights, and take authentication credentials for it.
  (Read Azure cloud documentation to perform this step)
- This installer designed to use Azure authentication via [ENV variables](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure?tabs=bash) (setup they first)
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






