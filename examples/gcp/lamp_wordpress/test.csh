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
p_file=@@meta/mysql_root.key
mysql_root_pass=$(GEN_password root $p_file)
mysql_wp_user="my_wordpress"
mysql_wp_pass=$(GEN_password $mysql_wp_user @@meta/mysql_wp_user.key)

######### DEPLOY GCP VM STAGE #################
~WP_VM:
####################  tvfars tuning variables/values
project_id=@@last
region=@@last
vpc_name=@@last
zone=@@last
machine_type="n2-standard-4"
boot_disk_size=@@last
boot_disk_type=@@
#boot_image="suse-cloud/sles-15" #checked #checked on 18.05.2024
#boot_image="opensuse-cloud/opensuse-leap" #checked on 18.05.2024
#boot_image="rhel-cloud/rhel-7" #checked on 18.05.2024
#boot_image="rhel-cloud/rhel-8" #checked on 18.05.2024
#boot_image="rhel-cloud/rhel-9" #checked on 18.05.2024
#boot_image="centos-cloud/centos-7" #checked on 18.05.2024
#boot_image="centos-cloud/centos-stream-8" #checked on 18.05.2024
#boot_image="centos-cloud/centos-stream-9" #checked on 18.05.2024
#boot_image="fedora-cloud/fedora-cloud-34" #????
#boot_image="fedora-cloud/fedora-cloud-37" #checked on 18.05.2024
#boot_image="fedora-cloud/fedora-cloud-38" #checked on 18.05.2024
#boot_image="fedora-cloud/fedora-cloud-39" #checked on 18.05.2024
boot_image="rocky-linux-cloud/rocky-linux-8" #checked on 18.05.2024
#boot_image="rocky-linux-cloud/rocky-linux-9" #checked on 18.05.2024
#boot_image="ubuntu-os-cloud/ubuntu-2004-lts" #checked on 18.05.2024
#boot_image="ubuntu-os-cloud/ubuntu-2204-lts" #checked on 18.05.2024
#boot_image="debian-cloud/debian-10" #checked on 18.05.2024
#boot_image="debian-cloud/debian-11" #checked on 18.05.2024
#boot_image="debian-cloud/debian-12" #checked on 18.05.2024

/* ############# inlined BASH part
case $boot_image in
*"ubuntu"*)
    ssh_user="ubuntu"
    http_service=apache2
    wp_owner="www-data:www-data"
    extra_pkgs="php libapache2-mod-php php-mysql php-curl php-pdo php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip fail2ban nano wget mc"
    wp_http_conf="/etc/$http_service/sites-enabled/wordpress.conf"
    www_home=/var/www/html
    ;;
*"debian"*)
    ssh_user="admin"
    http_service=apache2
    extra_pkgs="php libapache2-mod-php php-mysql php-curl php-pdo php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip fail2ban nano  wget mc"
    wp_http_conf="/etc/apache2/sites-enabled/wordpress.conf"
    www_home=/var/www/html
    ;;
*"suse"*)
    ssh_user="devops"
    http_service=apache2
    wp_owner="wwwrun:www"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/srv/www/htdocs
    case $boot_image in
    *"-leap")
        extra_pkgs="php apache2-mod_php81 php-zlib php-mbstring  php-pdo php-mysql php-opcache php-xml php-gd php-devel php-json fail2ban nano wget mc"
        ;;
    *"-15")
        suse_boot_delay=10
        extra_repo="https://download.opensuse.org/repositories/openSUSE:Backports:SLE-15-SP4/standard/openSUSE:Backports:SLE-15-SP4.repo"
        extra_pkgs="php apache2-mod_php8 php-zlib php-mbstring  php-pdo php-mysql php-opcache php-xml php-gd php-devel php-json fail2ban nano wget mc"
        ;;
    *) ;;
    esac
    ;;
*)
    ssh_user="devops"
    http_service=httpd
    wp_owner="apache:apache"
    extra_pkgs="php php-common php-gd php-xml php-mbstring mod_ssl php php-pdo php-mysqlnd php-opcache php-xml php-gd php-devel php-json mod_ssl fail2ban nano certbot wget mc"
    wp_http_conf="/etc/$http_service/conf.d/wordpress.conf"
    www_home=/var/www/html
    case $boot_image in
    *"-7")
        extra_repo=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        extra_repo_php="http://rpms.remirepo.net/enterprise/remi-release-7.rpm --enablerepo=remi-php74"
        ;;
    *"-8") extra_repo=https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm ;;
    *"-9") extra_repo=https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm ;;
    esac
    ;;
esac
*/

ssh_user=@@last
auto_key_public=@@meta/public.key
auto_key_private=@@meta/private.key
startup_script_file=@@

######### TF outputs returned parameters
walkman_install=@@self

############ setup deployment via HELPERs
set_FLOW fast
set_TARGET IP-public $ssh_user $auto_key_private
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
