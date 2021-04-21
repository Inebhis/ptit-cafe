#!/bin/sh

#--------------------- VARIABLES ---------------------#

# ip variable
ip=$(ip r g 1.2.3.4 | awk '{print $7}' | head -c-1)

#--------------------- INIT ---------------------#

yum -y update
yum -y upgrade
yum -y install vim

#--------------------- WEB ---------------------#

# Apache
yum -y install httpd
systemctl start httpd

# updating httpd.conf
sed -i 's/#Listen 12.34.56.78:80/Listen 127.0.0.1:8080/' /etc/httpd/conf/httpd.conf
sed -i 's/Listen 80/#Listen 80/' /etc/httpd/conf/httpd.conf
echo 'ServerName' $ip >> /etc/httpd/conf/httpd.conf 

systemctl restart httpd
systemctl enable httpd

# Mariadb
yum -y install mariadb-server mariadb
systemctl start mariadb
systemctl enable mariadb

# Secure mariadb
mysql --user=root <<_EOF_
  UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_

# PHP
yum -y install php php-mysql
systemctl restart httpd.service

# Test
echo "<?php phpinfo(); ?>" > /var/www/html/index.php

#--------------------- FAIL2BAN ---------------------#

# Install
yum install -y epel-release
yum install -y fail2ban

# Conf
echo "[DEFAULT]
bantime = 3600
findtime = 3600
maxretry = 3
[sshd]
enabled = true
port = 35539
[nginx-http-auth]
enabled = true
[nginx-botsearch]
enabled = true" > /etc/fail2ban/jail.local

systemctl start fail2ban
systemctl enable fail2ban

#--------------------- SSL ---------------------#

# Snap
yum install -y snapd
systemctl enable --now snapd.socket
ln -s /var/lib/snapd/snap /snap
snap install core; sudo snap refresh core

# nginx
yum -y install nginx
systemctl start nginx
systemctl enable nginx

# Désactivation de SELinux pour NGINX
semanage permissive -a httpd_t

#--------------------- FIREWALL - SSH ---------------------#

ssh_port=$((1000 + $RANDOM % 65635))
sshd_config="/etc/ssh/sshd_config"

systemctl start firewalld 
firewall-cmd --add-port=$ssh_port/tcp --permanent
firewall-cmd --reload

sed -i "s/# Port 22/Port $ssh_port/" $sshd_config
sed -i 's/#LoginGraceTime 2m/LoginGraceTime 2m/' $sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' $sshd_config
sed -i 's/#StrictModes yes/StrictModes yes/' $sshd_config

systemctl stop sshd
systemctl start sshd -p $ssh_port
systemctl enable sshd

#--------------------- REVERSE PROXY ---------------------#

# nginx setup
echo "user apache;
worker_processes auto;
events {
    worker_connections 1024;
}
http {
    server {
        listen       80 default_server;
        server_name  $ip;
        root         /var/www/html;
        location / {
            root    /var/www/html;
            proxy_pass http://127.0.0.1:8080/;
        }
    }
}" > /etc/nginx/nginx.conf

# proxy.conf
touch /etc/nginx/conf.d/proxy.conf
echo "client_max_body_size 10m;
client_body_buffer_size 128k;
proxy_connect_timeout 90;
proxy_send_timeout 90;
proxy_read_timeout 90;
proxy_buffer_size 4k;
proxy_buffers 4 32k;
proxy_busy_buffers_size 64k;
proxy_temp_file_write_size 64k;" > /etc/nginx/conf.d/proxy.conf

# html page
echo "\"La première loi sociale est celle qui garantit à tous les membres de la société les moyens d'existence ; toutes les autres sont subordonnées à celle-là ; la propriété n'a été instituée que pour la cimenter. [...] Tout ce qui est indispensable pour conserver [la vie] est un propriété commune à la société entière, il n'y a que l'excédent qui soit une propriété individuelle, et qui soit abandonné à l'industrie des commerçants.\" - Robespierre" > /var/www/html/index.html

# let's protect our back
chmod 755 /var/www/html/*.php

sudo chown apache:apache /var/www/html/index.*
chmod -R o-r /var/www/html/*
chmod -R o-x /var/www/html/*

# Certbot
yum remove -y certbot
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Run
certbot --nginx

systemctl restart httpd && systemctl restart nginx
