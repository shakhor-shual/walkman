server {
        listen 80;
        listen [::]:80;

        server_name ${DOMAIN};

        index index.php index.html index.htm;

        root /var/www/html;

        location ~ /.well-known/acme-challenge {
                allow all;
                root /var/www/html;
        }

        location / {
                try_files ${DOLLAR}uri ${DOLLAR}uri/ /index.php${DOLLAR}is_args${DOLLAR}args;
        }

        location ~ \.php${DOLLAR} {
                try_files ${DOLLAR}uri =404;
                fastcgi_split_path_info ^(.+\.php)(/.+)${DOLLAR};
                fastcgi_pass wordpress:9000;
                fastcgi_index index.php;
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME ${DOLLAR}document_root${DOLLAR}fastcgi_script_name;
                fastcgi_param PATH_INFO ${DOLLAR}fastcgi_path_info;
        }

        location ~ /\.ht {
                deny all;
        }

        location = /favicon.ico {
                log_not_found off; access_log off;
        }
        location = /robots.txt {
                log_not_found off; access_log off; allow all;
        }
        location ~* \.(css|gif|ico|jpeg|jpg|js|png)${DOLLAR} {
                expires max;
                log_not_found off;
        }
}
