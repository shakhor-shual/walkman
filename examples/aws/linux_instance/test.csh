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
debug@@@ 1   # possible here are 0, 1, 2, 3

~INSTACE_1:
region=eu-north-1
namespace=foxy
vpc_cidr_block=@@
subnet_cidr_block=@@
#ami="ami-0506d6d51f1916a96" #Debian 12
#ami="ami-010b74bc1a8b29122" #Ubuntu 20-04
#ami="ami-0914547665e6a707c" #Ubuntu 22-04
#ami="ami-02c621fe0333f4afb" #SUSE SLES-15
ami="ami-03035978b5aeb1274" #RHEL-9
#ami="ami-029e4db491be76287" # Amazon Linux 2023
#ami="ami-0f0ec0d37d04440e3" # Amazon Linux 2
volume_size=@@
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
instance_type="t3.micro"

#returned parameters
walkman_install=@@self
<<<INIT_access | "IP-public" | "ec2-user" | $auto_key_private

/* #inlined BASH
if [ -n "$walkman_install" ]; then
    echo "Wait 30 sec before Install Walkman on deployed VM"
    sleep 30
    eval $walkman_install
    echo $walkman_install
else
    echo "Can't Install Walkman"
fi
*/
