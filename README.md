# Walkman (Cloud Walkman For Devops)

### I express my deep gratitude to Amazon for providing sponsorship support of this project!

Walkman is a specialized kind of Unix shell (i.e. something like Bash, ash, zsh... etc.), 
designed to simplify a wide class of routine IaC operations for deploying and configuring 
cloud infrastructure. Walkman allows you to create directly executable Unix scripts  with a 
syntax that is maximally compatible with the syntax of [regular Bash](https://github.com/shakhor-shual/walkman/blob/main/examples/gcp/linux_vm/test.csh), and use them in the 
traditional Unix-native style (i.e., like any other types of shell scripts).
The example above shows: 

 - Customizing an existing terraform package using script-defined variables. 
 - Ability to use native inserts in pure Bash (located in /*....*/ blocks) 
 for additional manipulation of Walkman variables and performing any other 
 actions on the local system. 
 - The ability to use "helpers" ( i.e. internal Walkman functions),  to configure 
a deployed remote system. Relatively speaking, Walkman "helpers" are similar to the 
built-in commands of Unix shells, with the difference that the actions they perform are 
focused not on managing the operating system but on IAC tasks. In terms of  implementation, 
helpers are ordinary Bash functions predefined in Walkman itself. Therefore, the syntax 
for calling “helpers” in Walkman scripts is completely similar to the syntax for calling 
functions in Bash scripts. 

As you can see from the proposed example, all used helpers can be divided into 4 groups 
(by their prefixes and intended purpose) and into two groups (local/remote) according 
to target application:

- "do_*" group with names similar to Dockerfile directives (and they perform similar 
 operations BUT in relation to a deployed VM, not a container). This group of helpers 
 operates a REMOTE system!

- "set_*" group for simplified management of installation processes of operating system 
packages and other software components. This group of helpers operates a REMOTE system!

- "cmd_*" group of wrappers for commands/programs of the same(usually) name for example: 
rsync, kubectl, helm... etc, for direct management of remote deployments. The parameters 
for calling these helpers are the parameters for calling the corresponding commands/programs.
This group of helpers  operates a REMOTE system!

- "GET_" group is used to retrieve various data in the LOCAL system (for example, retrieves
 parameters from tfstate). This group of helpers operates a LOCAL system!


### Walkman for cloud deployment 
To deploy cloud infrastructure, Walkman uses Terraform and existing HCL projects. You can 
prepare any existing Terraform project to run under Walkman using the  command:
- cw4d describe

When you run this command in a folder containing a subfolder(s) with existing HCL project(s), 
a Walkman script template will be generated that controls the deployment of this project (with 
default parameters specified in the project itself). The template generator will add projects 
to the deployment script in alphabetical order of the names of sub-folders with HCL projects. 
The same procedure will be used in the process of subsequent infrastructure deployment. Remember 
this when choosing the names of sub-folders that satisfy the dependencies of the deployment stages!


### Walkman for post-deployment setup 
Ansible is used to configure the deployed infrastructure: 
- implicitly - using "helpers" that dynamically generate the necessary Ansible code 
- explicitly - by launching existing Ansible playbooks and roles. 

To do this, Walkman automatically generates a dynamic inventory for the entire infrastructure 
deployed by it.

Walkman uses Helm and kubectl to configure Kubernetes infrastructure deployment. Importing 
configuration for access to the cluster is recommended using Terraform

## Quick Start:
Walkman is just a single  bash script(cw4d.sh) that, when run without parameters, 
self-compiles itself into a Linux executable form (to ELF-file: /usr/local/bin/cw4d).
Before starting self-compilation, Walkman installs into the system all the missing 
components necessary for its subsequent operation (including: git, Terraform, 
Ansible-core, Helm, docker, kubectl etc). Components not found at the global level are 
installed mainly locally in the current user's home directory (in sub-folders of 
~/.local) to minimize the overall impact on the system. Thus, even if you do not plan 
to use the functionality of Walkman itself, its installation process can be used as a
way to quickly configure  any Linux system (including remote ones) for a wide range 
of common DevOps operations.

### Instant local installation - Linux(or WSL) only:
The easiest and fastest way to install Walkman locally - use one-string command:
- curl -s https://raw.githubusercontent.com/shakhor-shual/walkman/main/bin/cw4d.sh | sudo tee /usr/local/bin/cw4d.sh | bash

### Instant installation to remote host (to host Linux only)
The easiest and fastest way to install Walkman on a remote host is to use the 
"teleport" feature available in Walkman. To do this, you just need to have Walkman 
installed locally and run the command:
- cw4d.sh SSH_PARAMS_LIST 

in SSH_PARAMS_LIST possible use any valid options of ssh command e.g.:
- cw4d.sh -oStrictHostKeyChecking=no -i ~/.ssh/private.key user@host.domain.net

### More for local Walkman installation and usage - Linux(or WSL) only:
 - [read and use this info](https://github.com/shakhor-shual/walkman/tree/main/bin)

### More For in-cloud Walkman installation and usage (AWS/Azure/GCP):
 - [read and use this info](https://github.com/shakhor-shual/walkman/tree/main/self_deploy)

### Supported Distributions List
List of Linux distributions with tested support of Walkman (i.e. all external 
tools/components self-installation has been tested and works correctly):

- Amazon Linux 2, Amazon Linux 2023
- CentOS 7, *CentOS 8-stream, *CentOS 9-stream
- *RHEL-7, *RHEL-8, *RHEL-9
- *Rocky Linux 8, *Rocky Linux 9
- *Fedora 34, *Fedora 37, *Fedora 38, *Fedora 39 
- Ubuntu 20.04, Ubuntu 22.04, Ubuntu 24.04
- Debian 10, Debian 11, Debian 12
- SLES-12, SLES-15, OpenSUSE Leap

(*) distributions are marked in which the Walkman self-installer will install 
podman/podman-compose instead of the Docker toolset. In this case for extend 
general compatibility installer will create a symbolic links:  docker->podman
docker-compose -> podman compose.

### Auto-installing tools/components list:
The following tools are automatically installed by the Walkman self-installer (if 
they are not present on the system):

- (for IaC): Terraform, Ansible-core
- (for K8S): Helm, kubectl, k9s
- (common system): docker(or podman), git(+ tig), rsync, curl, wget, mc, nano 
- (base development): pip3, automake, gcc 

Working example projects with Walkman deployment scripts are provided in the 
[examples folder. The deployment scripting language](https://github.com/shakhor-shual/walkman/tree/main/examples) is an extremely 
simplified version of the Linux Shell languages. It will be intuitive to 
anyone who is familiar with Linux Shell scripts. You don't have to learn it, 
just forget 98% of what you need to know for BASH scripting and feel free 
to start writing your own deployment scripts with the remaining 2%;) The 
deployment scripts language syntax is as compatible as possible with existing 
shell programming support in major code editors. A nice bonus will be working 
syntax highlighting and auto-formatting of code in VS Code etc. 

Have a lot of fun ;)





