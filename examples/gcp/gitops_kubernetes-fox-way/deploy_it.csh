#!/usr/local/bin/cw4d
###########################################################################
# Copyright The Vadym Yanik.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#########################################################################
run@@@ = plan # possible here ( or|and in SHEBANG) are: plan, init, apply, destroy)
debug@@@ = 2  # possible here are 0, 1, 2, 3
#
#git@@@ git@github.com:shakhor-shual/kubernetes-the-fox-way-extras.git ^main >00_deploy_extra_nodes
git@@@ git@github.com:shakhor-shual/kubernetes-the-fox-way.git ^main >05_deploy_kubernetes_core

NS="plan9"
project_id="foxy-test-415019"
vpc_name="$NS-kube-vpc"
subnet_name="$NS-custom-subnet"
subnet_cidr="192.168.0.0/24"
kube_kind="k8raw"
kubernetes_release=1.28
ssh_user="ubuntu"

~INIT_CONTROL_PLANE:
kube_kind=@@last
kubernetes_release=@@last
project_id=@@last                                             # @@="some-roject"
region=n=europe-central2                                      # @@="us-central1"
zone="$region-c"                                              # @@="us-central1-c"
vpc_name=@@last                                               # @@="some-vpc"
subnet_list=["10.230.0.0/24","10.240.0.0/24","10.250.0.0/24"] # @@=["10.230.0.0/24","10.240.0.0/24","10.250.0.0/24"]
ingress_host="node-ingress"                                   # @@="node_ingress"
ssh_user=@@last                                               # @@="shual"
auto_key_public=@@meta/public.key                             # @@="../.meta/public.key"
auto_key_privare=@@meta/private.key                           # @@="../.meta/private.key"
custom_key_public = "~/.ssh/id_rsa_pub.pem"                   # @@="~/.ssh/id_rsa_pub.pem"
machine_type="n1-standard-1"                                  # @@="n1-standard-1"
powered_machine_type="n1-standard-2"                          # @@="n1-standard-2"
os_image="ubuntu-os-cloud/ubuntu-2004-lts"                    # @@="ubuntu-os-cloud/ubuntu-2004-lts"
os_disk_size=25                                               # @@=25
os_disk_type="pd-balanced"                                    # @@="pd-balanced"
nfs_pv_size =30                                               # @@=50
ddns_domain_ingress="none"
ddns_domain_bastion="none"
ddns_access_token="none"
<<<SET_access_artefacts | nat_ip | $ssh_user | $auto_key_privare
