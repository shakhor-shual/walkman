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
run@@@ = apply # possible here ( or|and in SHEBANG) are: validate, init, apply, destroy, new
debug@@@ = 2   # possible here are 0, 1, 2, 3

~WALKMAN:
region=eu-north-1
vpc_name="walkman-vpc"
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
instance_type="t3.micro"
ssh_user=ec2-user
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
<<<SET_access_artefacts | public_ip | $ssh_user | $auto_key_private
