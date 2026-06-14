#!/bin/bash
# Fix MySQL bind-address for remote access
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql
echo "MySQL remote access enabled"
