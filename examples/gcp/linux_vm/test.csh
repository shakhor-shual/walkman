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
run@@@ apply # possible here ( or|and in SHEBANG) are: validate, init, apply, destroy, new
debug@@@ 2   # possible here are 0, 1, 2, 3

# ROOT
/* #Example of inlined BASH usage
ext_size=30
((ext_size++))
*/
project_id="foxy-test-415019"
region="europe-west6"
zone="$region-b"
vpc_name="@@this-vpc"
host=@@this
boot_disk_size=$ext_size
/* # #Example of inlined BASH usage
((boot_disk_size++))
*/

######### DEPLOY GCP VM STAGE #################
~GCP_VM:
project_id=@@last
region=@@last
vpc_name=@@last
zone=@@last
machine_type="n2-standard-2"

/* #Example of inlined BASH usage
((boot_disk_size++))
echo $boot_disk_size
*/

boot_disk_size=@@last
boot_disk_type=@@
#boot_image="suse-cloud/sles-12"
#boot_image="suse-cloud/sles-15"
#boot_image="opensuse-cloud/opensuse-leap"
#boot_image="rhel-cloud/rhel-7" #checked
#boot_image="rhel-cloud/rhel-8" #checked
#boot_image="rhel-cloud/rhel-9" #checked
#boot_image="centos-cloud/centos-7" #checked
#boot_image="centos-cloud/centos-stream-8" #checked
#boot_image="centos-cloud/centos-stream-9" #checked
#boot_image="fedora-cloud/fedora-cloud-34" #checked
#boot_image="fedora-cloud/fedora-cloud-37" #checked
#boot_image="fedora-cloud/fedora-cloud-38" #checked
#boot_image="fedora-cloud/fedora-cloud-39"
#boot_image="rocky-linux-cloud/rocky-linux-8" #checked
#boot_image="rocky-linux-cloud/rocky-linux-9" #checked
#boot_image="ubuntu-os-cloud/ubuntu-2004-lts" #checked
boot_image="ubuntu-os-cloud/ubuntu-2204-lts" #checked
#boot_image="ubuntu-os-cloud/ubuntu-2404-lts"
#boot_image="debian-cloud/debian-10" #checked
#boot_image="debian-cloud/debian-11" #checked
#boot_image="debian-cloud/debian-12" #checked

#inlined BASH
/*
if [[ $boot_image =~ "ubuntu" ]]; then
    ssh_user="ubuntu"
else
    ssh_user="fedo"
fi
*/
ssh_user=@@last
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
startup_script_file=@@

#returned parameters
walkman_install=@@self

do_TARGET IP-public $ssh_user $auto_key_private
do_FROM all
do_WORKDIR /usr/local/bin
do_COPY $auto_key_public /usr/local/bin/public.key root:root
do_RUN "sudo apt install nano -y; pwd; ls -l"
do_HELM test
do_KUBECTL test

/* #inlined BASH
if [ -n "$walkman_install" ]; then
    #   echo "Wait 30 sec before Install Walkman on deployed VM"
    #   sleep 30
    #   eval $walkman_install
    echo $walkman_install
else
    echo "Can't Install Walkman"
fi
*/
