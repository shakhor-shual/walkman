# Walkman installer for GCP:
Before you proceed further, make sure that you have configured access to the cloud 
that you use to work with Terraform (authentication and authorization, rights to 
create objects, availability of APIs to use, etc., etc.). The necessary list of 
settings for Terraform to work is determined by the type of cloud provider used.
Also, read this README to the the end, to better understand your next steps

## For Walkman in-GCP installation:
- This installer designed to use standard [ADC authorization](https://cloud.google.com/docs/authentication/provide-credentials-adc) in GCP (setup it first)
- clone [repository](https://github.com/shakhor-shual/walkman/tree/main) to your machine 
- on Linux machine you can install Walkman before and use it to run cloud installer
- on all OS-kind machine you can deploy Walkman for in-cloud with Terraform only
- cd to folder: walkman/self_deploy/to_gcp 
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






