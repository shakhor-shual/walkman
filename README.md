# Walkman (Cloud Walkman For Devops)

Walkman is a tool for configuring and orchestrating mixed IaC projects
based on existing code-base for Terraform, Ansible, Helm, kubectl. To quickly 
understand what it is and why it is, just think of Walkman as something 
like "nano-Jenkins" designed exclusively for IaC operations. If this statement
seems excessive to you, you can consider it a helper tool for automating the
collaboration of Terraform & Ansible bunch for GitOps-like style. If even this 
seems too much, just think of Walkman as a dynamic inventory script that 
gives Ansible automatic access to setting up the infrastructure deployed 
and managed using with Walkman . Well, or just consider it a script for the 
automatic installation of a set of basic DevOps tools on a fresh Linux system 
(Debian/Ubuntu and CentOs/RHEL/Amazon Linux are supported). But in general, 
Walkman was conceived as a small "Swiss-Army-Knife" for DevOps routines. )

## Quick Start:
### For local Walkman installation and usage - Linux(or WSL) only:
 - [use this](https://github.com/shakhor-shual/walkman/tree/main/bin)

### For in-cloud Walkman installation and usage (AWS/Azure/GCP):
 - [use this](https://github.com/shakhor-shual/walkman/tree/main/self_deploy)

Working example projects with Walkman deployment scripts are provided in the 
[examples folder. The deployment scripting language](https://github.com/shakhor-shual/walkman/tree/main/examples) is an extremely 
simplified version of the Linux Shell languages. It will be intuitive to 
anyone who is familiar with Linux Shell scripts. You don't have to learn it, 
just forget 98% of what you need to know for BASH scripting and feel free 
to start writing your own deployment scripts with the remaining 2%;) The 
deployment scripts language syntax is as compatible as possible with existing 
shell programming support in major code editors. A nice bonus will be working 
syntax highlighting and auto-formatting of code in VS Code etc. Have a fun ;)





