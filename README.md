# Walkman (Cloud Walkman For Devops)

Walkman is a tool for configuring and orchestrating mixed IaC projects based on
existing code-base for Terraform, Ansible, Helm, docker, kubectl etc. To quickly 
understand what it is and why it is, just think of Walkman as something like 
"nano-Jenkins" designed exclusively for IaC operations. If this statement seems 
excessive to you, consider it as a helper tool for automating the collaboration
of Terraform & Ansible bunch for GitOps-like style. If even this seems too much, 
just think of Walkman as a dynamic inventory script that gives Ansible automatic 
access to setting up the infrastructure deployed and managed using with Walkman. 
If all of the above doesn't interest you, just consider this as script to 
automatically install a bunch of core DevOps tools on a new Linux system 
(Debian/Ubuntu and CentOs/RHEL/Amazon Linux are supported). In general, Walkman 
was conceived as a small “Swiss Army knife” for DevOps-routines. 

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

Working example projects with Walkman deployment scripts are provided in the 
[examples folder. The deployment scripting language](https://github.com/shakhor-shual/walkman/tree/main/examples) is an extremely 
simplified version of the Linux Shell languages. It will be intuitive to 
anyone who is familiar with Linux Shell scripts. You don't have to learn it, 
just forget 98% of what you need to know for BASH scripting and feel free 
to start writing your own deployment scripts with the remaining 2%;) The 
deployment scripts language syntax is as compatible as possible with existing 
shell programming support in major code editors. A nice bonus will be working 
syntax highlighting and auto-formatting of code in VS Code etc. Have a fun ;)





