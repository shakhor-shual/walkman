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

p_file=@@meta/mysql_root.key
mysql_root_pass=$(GEN_password root $p_file)
mysql_wp_user="my_wordpress"
mysql_wp_pass=$(GEN_password $mysql_wp_user @@meta/mysql_wp_user.key)

~INSTACE_1:
region=eu-north-1
namespace=foxy2
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

/* ############# inlined BASH part
case $boot_image in
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
    extra_pkgs="php apache2-mod_php8 php-zlib php-mbstring  php-pdo php-mysql php-opcache php-xml php-gd php-devel php-json fail2ban nano wget mc"
    ;;
"ami-03035978b5aeb1274")
    ssh_user="ec2-user" #RHEL-9
    http_service=httpd
    wp_owner="apache:apache"
    extra_pkgs="php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    extra_repo=https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    ;;
"ami-0f0ec0d37d04440e3")
    ssh_user="ec2-user" # Amazon Linux 2
    http_service=httpd
    wp_owner="apache:apache"
    extra_pkgs="php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    amazon2_extras="sudo amazon-linux-extras install epel -y"
    ;;
"ami-029e4db491be76287")
    ssh_user="ec2-user" #  # Amazon Linux 2023
    http_service=httpd
    wp_owner="apache:apache"
    extra_pkgs="php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    amazon_extras="sudo amazon-linux-extras install epel -y"
    ;;
esac
*/

######### TF outputs returned parameters
walkman_install=@@self

############ setup deployment via HELPERs
set_FLOW fast
set_TARGET "IP-public" "ec2-user" $auto_key_private
#set_TARGET IP-public $ssh_user $auto_key_private
do_FROM all
cmd_SLEEP $on_boot_delay
set_REPO $extra_repo
set_MARIADB root $mysql_root_pass
cmd_SQL "CREATE DATABASE IF NOT EXISTS wordpress;GRANT ALL PRIVILEGES on wordpress.* to '$mysql_wp_user'@'localhost' identified by '$mysql_wp_pass';FLUSH PRIVILEGES;"
set_APACHE
do_ADD http://wordpress.org/latest.tar.gz $www_home/ $wp_owner 0755
do_RUN "sudo find $www_home/wordpress -type f -exec chmod 644 {} \;"
set_REPO $extra_repo_php
set_PACKAGE $extra_pkgs
do_ADD @@meta/wordpress.conf $wp_http_conf root:root
do_ADD @@meta/wp-config.php $www_home/wordpress/wp-config.php $wp_owner
set_APACHE WORDPRESS_DB_HOST="localhost" WORDPRESS_DB_USER="$mysql_wp_user" WORDPRESS_DB_PASSWORD="$mysql_wp_pass" WORDPRESS_DB_NAME="wordpress" APACHE_LOG_DIR="/var/log/$http_service" APACHE_DOCUMENT_ROOT="$www_home"

set_PLAY
cmd_INTERACT

/*
echo $mysql_root_pass
#hhhx
#/bin/ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i /home/ubuntu/github/walkman/examples/gcp/linux_wordpress/.meta/private.key devops@34.65.146.167
if [ -n "$walkman_install" ]; then
    #   echo "Wait 30 sec before Install Walkman on deployed VM"
    #   sleep 30
    #   eval $walkman_install
    echo "http://"

else
    echo "Can't Install Walkman"
fi
*/
