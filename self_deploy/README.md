# Walkman in-cloud installation:
Before you proceed further, make sure that you have configured access to the cloud 
that you use to work with Terraform (authentication and authorization, rights to 
create objects, availability of APIs to use, etc., etc.). The necessary list of 
settings for Terraform to work is determined by the type of cloud provider used.
Also, read this README to the the end, to better understand your next steps

ForWalkman in-cloud installation:
- clone this repository your machine with Terraform installed
- on Linux you can install Walkman before and use it to run cloud-specific installers
- on all OS-kind machine you can deploy Walkman for in-cloud with Terraform only
- cd to walkman/self_deploy folder and choose installer for desired cloud
- cd to chosen cloud-type installer folder
- if Walkman installed locally, deploy installer to cloud via Walkman 
- otherwise, you can deploy Walkman in the cloud using only Terraform 
- find in installer folder Terraform package sub-folder and cd to it
- modify tfvars.template file accordingly to you requirements and cloud settings
- run: mv tfvars.template terraform.tfvars; terraform init && terraform apply
- connect to deployed VM via SSH for operate with in-cloud Walkman node






