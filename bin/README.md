# Walkman HOW-TO
## Local installation
For install Walkman locally (Linux || WSL only!):
- clone this repository to your machine
- check&enable ability to run sudo command without password asking
- cd to walkman/bin folder and execute script: ./cw4d.sh

## Local usage
Before you proceed further, make sure that you have configured access 
to the cloud that you use to work with Terraform (authentication and 
authorization, rights to create objects, availability of APIs to use etc). 
The necessary list of settings for Terraform to work is determined by the 
type of cloud provider used. Also, recommended to read Walkman READMEs,
for better understanding each your next step.

- choose any example project in  [walkman/examples](https://github.com/shakhor-shual/walkman/tree/main/examples) which you like
- modify it deployment script accordingly to you cloud-access settings
- run this deployment script with desired option, for example: 
   ./deploy_it.csh init (or/and ./deploy_it.csh plan  ...etc)

### Walkman implementation:
Walkman implemented as a single BASH script (cw4d.sh). After running this script,
it will automatically self-compile itself into the ELF executable file - cw4d 
( i.e. an acronym for Cloud Walkman For Devops) and will install itself 
for future use. In this form, Walkman can perform end-to-end cloud 
infrastructure management, including deployment/destruction and infrastructure 
configuration. The process of deploying and configuring the infrastructure 
itself is performed using the tools listed above. Walkman installs 
automatically all used DevOps tools if they are not on the system.

The IaC project for Walkman consists of a sequence of stages (actually this 
is Iac pipeline). Each stage is organized as a separate subfolder within the 
project folder. Each stage subfolder can contain code for ONLY ONE of the 
DevOps tools listed above. Walkman automatically determines the type of tool 
used for each stage based on the subfolder content. During the process of 
deploying and configuring infrastructure, project stages are performed by 
Walkman in alphabetical order of subfolder stage names. The process of 
destroying the infrastructure is carried out in reverse order (the stages 
involved in the configuration processes are skipped).

The description of the deployment orchestration process is declarative,
and is written in a primitive shell-like DSL language. Process description 
files are called "deployment scripts". They should be stored in a root of
project folder, they should have a reserved *.csh extension and they shebang 
string should looks like:  #!/usr/local/bin/cw4d [OPTION]

The basic OPTIONS for manual usage are completely repeat the Terraform 
options of the same name (i.e. init, plan, deploy, destroy). The actions 
they perform are similar. Like other shell-kind scripts, deployment scripts 
are executable. The action that will be performed when the script is launched 
is determined by the option specified in the shebang, or by the option 
passed in the script launch parameters (takes priority over the shebang 
written options). This also means that you can run the deployment script 
manually (or as a regular cron job), with the "gitops" option. In the 
latter case, Walkman will track (and apply to infrastructure) changes in 
the Git repositories of the IaC code  specified in the deployment script.
Each project deployment script uses a separate Terraform workspace, which 
allows you to use one IaC project code base for parallel management of 
several environments (ака dev/test/prod, etc.)


### Walkman Helpers 
The helpers (look like this: <<<name | value-1 ... | value-N) actually 
are a syntactic wrapper for directly using the Walkman BASH-function 
in deployment scripts. The  "name" of helper in deployment script must 
be a name of an existing function in the Walkman (i.e., an internal 
function programmed in BASH which is part of the Walkman source code). 
The concept of helpers is intended for quick, problem-oriented expansion 
of the functionality of deployment scripts by adding new specialized BASH
functions to the Walkman source code with the possibility of their 
subsequent direct calling in deployment scripts. The Walkman architecture 
allows the helper to return a single string, the contents of which can 
be assigned to a deployment script variable (or ignored if the helper is 
called outside of a variable assignment operation). In the latter case, 
it is assumed that the purpose of calling the helper was to generate 
some artifacts in the file structure of the project.
