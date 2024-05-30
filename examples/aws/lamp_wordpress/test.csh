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

p_file=@@vault/mysql_root.key
mysql_root_pass=$(GEN_password root $p_file)
mysql_wp_user="my_wordpf"
mysql_wp_pass=$(GEN_password $mysql_wp_user @@vault/mysql_wp_user.key)

~INSTACE_1:
region=eu-north-1
namespace=foxy3
vpc_cidr_block=@@
subnet_cidr_block=@@
#ami="ami-0506d6d51f1916a96" #Debian 12
#ami="ami-010b74bc1a8b29122" #Ubuntu 20-04
#ami="ami-0914547665e6a707c" #Ubuntu 22-04
#ami="ami-02c621fe0333f4afb" #SUSE SLES-15
#ami="ami-03035978b5aeb1274" #RHEL-9
#ami="ami-029e4db491be76287" # Amazon Linux 2023
ami="ami-0f0ec0d37d04440e3" # Amazon Linux 2
volume_size=@@
auto_key_public=@@vault/public.key
auto_key_private=@@vault/private.key
instance_type="t3.micro"

/* ############# inlined BASH part
db_pkgs="mariadb mariadb-server"
db_service="mariadb"

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
    http_service=apache2
    extra_pkgs="php libapache2-mod-php php-mysql php-curl php-pdo php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip fail2ban nano  wget mc"
    wp_http_conf="/etc/apache2/sites-enabled/wordpress.conf"
    www_home=/var/www/html
    ;;
"ami-02c621fe0333f4afb")
    ssh_user="admin" # Debian-12
    http_service=apache2
    wp_owner="wwwrun:www"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/srv/www/htdocs
    suse_boot_delay=10
    extra_repo="https://download.opensuse.org/repositories/openSUSE:Backports:SLE-15-SP4/standard/openSUSE:Backports:SLE-15-SP4.repo"
    extra_pkgs="$http_service $db_pkgs php apache2-mod_php8 php-zlib php-mbstring  php-pdo php-mysql php-opcache php-xml php-gd php-devel php-json fail2ban nano wget mc"
    ;;
"ami-03035978b5aeb1274")
    ssh_user="ec2-user" #RHEL-9
    http_service=httpd
    wp_owner="apache:apache"
    extra_pkgs="$http_service $db_pkgs php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    extra_repo=https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    ;;
"ami-0f0ec0d37d04440e3")
    ssh_user="ec2-user" # Amazon Linux 2
    http_service=httpd
    wp_owner="apache:apache"
    extra_pkgs="$http_service $db_pkgs php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    extra_repo="amazon-linux-extras install epel -y"
    extra_repo_php="amazon-linux-extras enable php8.2; amazon-linux-extras enable mariadb10.5"
    ;;
"ami-029e4db491be76287")
    ssh_user="ec2-user" #  # Amazon Linux 2023
    http_service=httpd
    db_pkgs="mariadb105 mariadb105-server"
    db_service="mariadb"
    wp_owner="apache:apache"
    extra_pkgs="$http_service $db_pkgs php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    ;;
esac

case $instance_type in
*"g."* | *"g") pkg_arch="arm64" ;;
*) pkg_arch="amd64" ;;
esac
*/

######### TF outputs returned parameters
walkman_install=@@self

############ setup deployment via HELPERs
set_TARGET "IP-public" $ssh_user $auto_key_private
do_FROM all

#Install Wodrpess
do_REPO $extra_repo
do_REPO $extra_repo_php
do_PACKAGE $extra_pkgs
do_ENTRYPOINT $db_service
cmd_MYSQL_SECURE root $mysql_root_pass
cmd_MYSQL "CREATE DATABASE IF NOT EXISTS wordpress;GRANT ALL PRIVILEGES on wordpress.* to '$mysql_wp_user'@'localhost' identified by '$mysql_wp_pass';FLUSH PRIVILEGES;"
do_ENV $http_service WORDPRESS_DB_HOST="localhost" WORDPRESS_DB_USER="$mysql_wp_user" WORDPRESS_DB_PASSWORD="$mysql_wp_pass" WORDPRESS_DB_NAME="wordpress" APACHE_LOG_DIR="/var/log/$http_service" APACHE_DOCUMENT_ROOT="$www_home"
do_ADD http://wordpress.org/latest.tar.gz $www_home/wordpress $wp_owner 0755
do_RUN "sudo find $www_home/wordpress -type f -exec chmod 644 {} \;"
do_ADD @@assets/wordpress.conf $wp_http_conf root:root
do_ADD @@assets/wp-config.php $www_home/wordpress/wp-config.php $wp_owner
do_ENTRYPOINT $http_service

# # # Install Prometheus
do_RUN "id -u prometheus &>/dev/null || sudo useradd --no-create-home --shell /bin/false prometheus"
do_ADD https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-$pkg_arch.tar.gz /etc/prometheus/ prometheus:prometheus
do_ADD @@assets/prometheus.yml /etc/prometheus/prometheus.yml prometheus:prometheus
do_ADD @@assets/prometheus.service /etc/systemd/system/prometheus.service root:root
do_VOLUME /var/lib/prometheus
do_MOVE /etc/prometheus/prometheus /usr/local/bin/prometheus
do_MOVE /etc/prometheus/promtool /usr/local/bin/promtool
do_RUN "sudo chown prometheus:prometheus /usr/local/bin/prometheus; sudo chown prometheus:prometheus /usr/local/bin/promtool; sudo chown -R prometheus:prometheus /var/lib/prometheus"
do_ENTRYPOINT prometheus

# #  Install Prometheus node_exporter
do_ADD https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-$pkg_arch.tar.gz /opt/node_exporter root:root
do_ADD @@assets/node_exporter.service /etc/systemd/system/node_exporter.service root:root
do_ENTRYPOINT node_exporter
#  Install Prometheus mysqld_exporter
do_ADD https://github.com/prometheus/mysqld_exporter/releases/download/v0.14.0/mysqld_exporter-0.14.0.linux-$pkg_arch.tar.gz /opt/mysqld_exporter root:root
do_ADD @@assets/mysqld_exporter.service /etc/systemd/system/mysqld_exporter.service root:root
do_ENTRYPOINT mysqld_exporter
# #  Install Prometheus blackbox_exporter
do_ADD https://github.com/prometheus/blackbox_exporter/releases/download/v0.23.0/blackbox_exporter-0.23.0.linux-$pkg_arch.tar.gz /opt/blackbox_exporter root:root
do_ADD @@assets/blackbox.yml /opt/blackbox_exporter/blackbox.yml root:root
do_ADD @@assets/blackbox_exporter.service /etc/systemd/system/blackbox_exporter.service root:root
do_ENTRYPOINT blackbox_exporter

# Install Grafana
do_REPO @@assets/grafana.repo
do_PACKAGE grafana
do_ENTRYPOINT grafana-server
/*
echo -e
echo "================ Quick acces to deployment components via SSH tunnel: ================="
echo -e
echo "  Wordpress  -> http://localhost:8080"
echo "  Prometheus -> http://localhost:9090"
echo "  Grafana    -> http://localhost:3000"
echo -e
echo "======================================================================================="
*/

cmd_INTERACT -L 8080:localhost:80 -L 3000:localhost:3000 -L 9090:localhost:9090
