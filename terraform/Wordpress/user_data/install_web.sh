#!/bin/bash
yum update -y
yum install -y httpd

groupadd www
usermod -a -G www ec2-user
chown -R root:www /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} +
find /var/www -type f -exec chmod 0664 {} +


chkconfig httpd on
amazon-linux-extras disable php7.2
amazon-linux-extras disable lamp-mariadb10.2-php7.2
amazon-linux-extras enable php7.4
yum install -y php-cli php-pdo php-fpm php-json php-mysqlnd php-gd php-dom php-mbstring php-opcache polkit ImageMagick ImageMagick-devel ImageMagick-c++-devel


cd /var/www/html
wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
rm -f latest.tar.gz
mv wordpress blog
cd blog
mv wp-config-sample.php wp-config.php
chown -R apache:apache /var/www/html/blog

yum install -y htop


## Manual steps
# sudo vi /var/www/html/blog/wp-config.php
#   Modify the database connection parameters as follows:
#   define(‘DB_NAME’, ‘blog’);
#   define(‘DB_USER’, ‘root’);
#   define(‘DB_PASSWORD’, ‘YOUR_PASSWORD’);
#   define(‘DB_HOST’, IP_OF_DB);
# sudo service httpd restart