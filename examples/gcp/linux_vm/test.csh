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
debug@@@ 0   # possible here are 0, 1, 2, 3

# ROOT
project_id="foxy-test-415019"
region="europe-west6"
zone="$region-b"
vpc_name="@@this-vpc"
host=@@this

~GCP_VM:
project_id=@@last
region=@@last
vpc_name=@@last
zone=@@last
machine_type="n2-standard-2"
boot_disk_size=30
boot_disk_type=@@
boot_image="ubuntu-os-cloud/ubuntu-2004-lts"
ssh_user=devops
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
startup_script_file=@@
<<<SET_access_artefacts | IP-public | $ssh_user | $auto_key_private
