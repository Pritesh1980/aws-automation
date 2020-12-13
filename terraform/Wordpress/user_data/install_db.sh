#!/bin/bash
yum update -y

yum install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb


## Manual steps
# sudo mysql_secure_installation
# sudo mysql -uroot -p
#   create database blog; 
#   GRANT ALL ON blog.* to 'root'@'%' IDENTIFIED BY 'ENTER_PASSWORD_HERE' WITH GRANT OPTION;
