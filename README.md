# walkman

Walkman is a tool for configuring and orchestrating complex IaC projects
based on existing code for Terraform, Ansible, Helm, kubectl. It is 
implemented as a single BASH script (cw4d.sh). After running this script,
it will automatically compile itself into the ELF executable file - cw4d 
(i.e. an acronym for Cloud Walkman For Devops) and will install itself 
for future use. In this form, Walkman can perform end-to-end cloud 
infrastructure management, including deployment/destruction and infrastructure 
configuration. The process of deploying and configuring the infrastructure 
itself is performed using the tools listed above (which Walkman installs 
automatically if they are not on the system).

The IAC project for Walkman consists of a sequence of stages. Each stage is 
organized as a separate subfolder within the project folder. Each stage 
subfolder can contain code for ONLY ONE of the tools listed above. Walkman 
automatically determines the type of tool used for each stage based on the 
subfolder content. During the process of deploying and configuring infrastructure, 
project stages are performed by Walkman in alphabetical order of subfolder 
stage names. The process of destroying the infrastructure is carried out 
in reverse order (the stages involved in the configuration processes are 
skipped)

The description of the deployment orchestration process is declarative,
and is written in a primitive shell-like DSL language. Process description 
files are called "deployment scripts". They should be stored in a root of
project folder, should have a reserved *.csh extension and they shebang 
string should looks like:  #!/usr/local/bin/cw4d [OPTION]

The basic OPTIONS completely repeat the Terraform options of the same 
name (i.e. init, plan, deploy, destroy). The actions they perform are 
similar. Like other shell scripts, deployment scripts are executable. 
The action that will be performed when the script is launched is 
determined by the option specified in the shebang, or by the option 
passed in the script launch parameters (takes priority over the shebang 
written options). 

If everything written here seems confusing to you, just think of Walkman 
as something like nano-Jenkins, designed exclusively for IaC pipelines, 
but with GitOps support and dynamic inventory generation mode for Ansible 
(yes, that's true)... 
