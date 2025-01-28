#!/bin/bash
yum update -y
yum install httpd -y
cd /var/www/html
echo "<html><body><h1> Hello Terraform $(hostname -f) </h1></body></html>" > index.html
systemctl restart httpd
systemctl enable httpd