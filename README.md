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
Before you proceed further, make sure that you have configured access to the cloud 
that you use to work with Terraform (authentication and authorization, rights to 
create objects, availability of APIs to use, etc., etc.). The necessary list of 
settings for Terraform to work is determined by the type of cloud provider used.
Also, read this README to the the end, to better understand your next steps

### For local Walkman installation and usage (Linux OR WSL only):
- clone this repository to your machine
- check&enable ability to run sudo command without password asking
- cd to walkman/bin folder and run ./cw4.d.sh script
- choose any example project in  walkman/examples which you like
 - modify it deployment script accordingly to you cloud-access settings
 - run this deployment script with desired option, for example: 
   ./deploy_it.csh init (or/and ./deploy_it.csh plan  ...etc)

### For in-cloud Walkman installation and usage:
 - [read and use this info](https://github.com/shakhor-shual/walkman/tree/main/self_deploy)

Working example projects and Walkman deployment scripts are provided in the 
examples section. The deployment scripting language is an extremely 
simplified version of the Linux Shell languages. It will be intuitive to 
anyone who is familiar with Linux Shell scripts. You don't have to learn it, 
just forget 98% of what you need to know for BASH scripting and feel free 
to start writing your own deployment scripts with the remaining 2%;) The 
deployment scripts language syntax is as compatible as possible with existing 
shell programming support in major code editors. A nice bonus will be working 
syntax highlighting and auto-formatting of code in VS Code etc. Have a fun ;)

for more details about Walkman implementation [look this](https://github.com/shakhor-shual/walkman/tree/main/bin)
for more details about Walkman syntax and examples [look this](https://github.com/shakhor-shual/walkman/tree/main/examples)




