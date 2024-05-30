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
speed@@@ 1

# Set used versions of docker/docker-compose !!!FULL(MAJOR|MINOR) EXISTED VERSIONS ONLY!!!
docker_version="26.1.3"
docker_compose_version="2.27.0"

# Uncomment ONE used Linux distro
#ami="ami-0506d6d51f1916a96" #Debian 12
#ami="ami-010b74bc1a8b29122" #Ubuntu 20-04
#ami="ami-0914547665e6a707c" #Ubuntu 22-04
#ami="ami-029e4db491be76287" # Amazon Linux 2023
ami="ami-0f0ec0d37d04440e3" # Amazon Linux 2

~INSTACE_1:
region=eu-north-1
namespace=foxy4
vpc_cidr_block=@@
subnet_cidr_block=@@
volume_size=@@
auto_key_public=@@vault/public.key
auto_key_private=@@vault/private.key
instance_type="t3.micro"
ami=@@last

/*
case $instance_type in
*"g."* | *"g") instance_arch="aarch64" ;;
*) instance_arch="x86_64" ;;
esac
*/

############ setup deployment via HELPERs
set_TARGET "IP-public" $ssh_user $auto_key_private
do_FROM all

# Install Docker from binaries
do_ADD https://download.docker.com/linux/static/stable/$instance_arch/docker-$docker_version.tgz /usr/bin/ root:root
do_ADD https://github.com/docker/compose/releases/download/v$docker_compose_version/docker-compose-linux-$instance_arch /usr/local/lib/docker/cli-plugins/docker-compose root:root 0755
do_ADD @@meta/docker.socket /etc/systemd/system/docker.socket root:root
do_ADD @@meta/docker.service /etc/systemd/system/docker.service root:root
do_VOLUME /etc/docker root:root 0755
do_RUN "sudo cp -lf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose"
do_RUN "sudo groupadd -f docker; sudo usermod -aG docker $ssh_user"
do_ENTRYPOINT docker

cmd_INTERACT -L 8080:localhost:80 -L 3000:localhost:3000 -L 9090:localhost:9090
