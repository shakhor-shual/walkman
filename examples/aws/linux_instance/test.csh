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
ami=@@
volume_size=@@
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
instance_type="t3.micro"
<<<SET_access_artefacts | "IP-public" | "ec2-user" | $auto_key_private
