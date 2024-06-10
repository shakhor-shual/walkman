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
protect@@@ ~INSTACE_NETWORK
run@@@ apply # possible here ( or|and in SHEBANG) are: validate, init, apply, destroy, new
debug@@@ 2   # possible here are 0, 1, 2, 3
speed@@@ 3

# Set used versions of docker/docker-compose !!!FULL(MAJOR|MINOR) EXISTED VERSIONS ONLY!!!
docker_version="26.1.3"
docker_compose_version="2.27.0"

# Uncomment ONE used Linux distro
#ami="ami-0506d6d51f1916a96" #Debian 12
#ami="ami-010b74bc1a8b29122" #Ubuntu 20-04
#ami="ami-0914547665e6a707c" #Ubuntu 22-04
#ami="ami-029e4db491be76287" # Amazon Linux 2023
ami="ami-0f0ec0d37d04440e3" # Amazon Linux 2

~INSTACE_EIP:
region=eu-north-1
elastic_ip_id=@@self

~INSTACE_NETWORK:
region=@@last
namespace=foxy4
vpc_cidr_block=@@
subnet_cidr_block=@@
#------------------
vps_id=@@self
subnet_id=@@self
security_group_id=@@self

~INSTACE_1:
region=eu-north-1
namespace=@@last
subnet_id=@@last
security_group_id=@@last
volume_size=@@
auto_key_public=@@vault/public.key
auto_key_private=@@vault/private.key
instance_type="t3.micro"
ami=@@last
elastic_ip_id=@@last

/*
case $ami in
"ami-010b74bc1a8b29122" | "ami-0914547665e6a707c")
    ssh_user="ubuntu" #Ubuntu 20-04 & 22-04
    http_service=apache2
    wp_owner="www-data:www-data"
    extra_pkgs="php libapache2-mod-php php-mysql php-curl php-pdo php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip fail2ban nano wget mc"
    wp_http_conf="/etc/$http_service/sites-enabled/wordpress.conf"
    www_home=/var/www/html
    ;;
"ami-0506d6d51f1916a96")
    ssh_user="ec2-user" #SUSE SLES-15
    ;;
"ami-02c621fe0333f4afb")
    ssh_user="admin" # Debian-12
    ;;
"ami-03035978b5aeb1274")
    ssh_user="ec2-user" #RHEL-9
    ;;
"ami-0f0ec0d37d04440e3")
    ssh_user="ec2-user" # Amazon Linux 2
    ;;
"ami-029e4db491be76287")
    ssh_user="ec2-user" #  # Amazon Linux 2023
    ;;
esac

case $instance_type in
*"g."* | *"g") instance_arch="aarch64" ;;
*) instance_arch="x86_64" ;;
esac

templates=/home/$ssh_user/templates
compose_lib=$templates/docker-compose
*/

############ setup deployment via HELPERs
set_TARGET "IP-public" $ssh_user $auto_key_private
do_FROM all

############################################################################
# Install Docker from binaries possible in any of 2 ways, uncomment chosen
#  and comment alternatives
############################################################################

############## WAY 1:
# do_ADD https://download.docker.com/linux/static/stable/$instance_arch/docker-$docker_version.tgz /usr/bin/ root:root
# do_ADD https://github.com/docker/compose/releases/download/v$docker_compose_version/docker-compose-linux-$instance_arch /usr/local/lib/docker/cli-plugins/docker-compose root:root 0755
# do_ADD @@assets/docker.socket /etc/systemd/system/docker.socket root:root
# do_ADD @@assets/docker.service /etc/systemd/system/docker.service root:root
# do_VOLUME /etc/docker root:root 0755
# do_RUN "sudo cp -lf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose"
# do_RUN "sudo groupadd -f docker; sudo usermod -aG docker $ssh_user"
# do_ENTRYPOINT docker

############## WAY 2:
#do_PLAYBOOK @@assets/docker-install-playbook.yaml

############## WAY 3:
#set_DOCKER $docker_version $docker_compose_version

do_PACKAGE mc
do_ADD https://github.com/shakhor-shual/templates.git $templates
do_ADD @@vault/wordpress.env $compose_lib/wordpress/.env
do_ADD @@assets/wordpress/nginx-conf $compose_lib/wordpress/

do_COMPOSE $compose_lib/duckdns $compose_lib/prometheus $compose_lib/nodeexporter $compose_lib/cadvisor $compose_lib/grafana
do_VOLUME /var/lib/grafana docker:docker 0777
do_VOLUME /var/lib/grafana/dashboards docker:docker 0777
do_VOLUME /var/log/grafana docker:docker 0777
do_ADD @@assets/dashboards.yml grafana:/etc/grafana/provisioning/dashboards/dashboards.yml
do_ADD @@assets/datasources.yml grafana:/etc/grafana/provisioning/datasources/datasources.yml
do_ADD https://grafana.com/api/dashboards/1860/revisions/37/download grafana:/var/lib/grafana/dashboards/node-exporter-dashboard.json
do_ADD https://grafana.com/api/dashboards/19908/revisions/1/download grafana:/var/lib/grafana/dashboards/cadvisor-dashboard.json grafana_ds=prometheus
do_COMPOSE $compose_lib/grafana

do_WORKDIR $compose_lib/wordpress
do_ARG @@vault/domain.env
do_RUN "envsubst <nginx-conf/nginx.conf-0.tpl > nginx-conf/nginx.conf"
#do_COMPOSE $compose_lib/wordpress
do_ADD https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf $compose_lib/wordpress/nginx-conf/options-ssl-nginx.conf
do_RUN "sudo -E docker compose exec webserver ls -la /etc/letsencrypt/live || echo 'DNS not READY!!'"
#do_RUN "sudo -E docker compose exec webserver ls -la /etc/letsencrypt/live || sudo -E docker compose up -d --force-recreate --no-deps certbot"
#do_RUN "sudo -E docker compose exec webserver ls -la /etc/letsencrypt/live && envsubst <nginx-conf/nginx.conf-1.tpl > nginx-conf/nginx.conf && sudo -E docker compose up -d --force-recreate --no-deps webserver"
cmd_INTERACT -L 8000:localhost:80 -L 4443:localhost:443 -L 8080:localhost:8080 -L 3000:localhost:3000 -L 9090:localhost:9090
