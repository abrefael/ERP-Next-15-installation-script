#!/bin/bash


cat << EOF
This script was created to easily deploy Frappe-bench and\or ERP-Next 15 on a clean Ubuntu 22.04 minimal server
You are required to have a frappe-dedicated user and the ability to SSH to your server with this user. In addition, the frappe-dedicated user, should have sudo permissions on the server. If you have the above we will guide you through the setup process.
The process is constructed of a few parts:

1. Setting the system time zone.
2. Installing some prerequisites.
3. configuring the beckend server (a mariaDB instance).
4. installing the base infrastructure (i.e.: Node, npm and yarn)
5. Installing Frappe-bench and initializing it.
6. (Optional) setting up a new site.
7. (Optional) Installing ERP-Next.
8. (Optional) Making your server ready for production.

This script is based on guide by shashank_shirke on the Frappe Forum:
https://discuss.frappe.io/t/guide-how-to-install-erpnext-v15-on-linux-ubuntu-step-by-step-instructions/111706

Good luck :-)

EOF

echo "Let's begin with your timezone."
echo -e "What is your time zone?\n (Hint: if you don't know your time zone identifier, checkout the following Wikipedia page:\nhttps://en.wikipedia.org/wiki/List_of_tz_database_time_zones)"
read -p "" timez
timedatectl set-timezone "$timez"
read -s -p "Please enter sudo password: " passwrd
read -s -p "Please enter mysql root password: " sql_passwrd
read -p "Let's Update the system first. Please hit Enter to start..."
sudo apt-get update -y
sudo apt-get upgrade -y
read -p "Now, we'll install some prerequisites. Please hit Enter to start..."
echo $passwrd | sudo -S apt -qq install nano git curl -y
echo $passwrd | sudo -S apt -qq install python3-dev python3.10-dev python3-pip -y
echo $passwrd | sudo -S apt -qq install python3.10-venv -y
echo $passwrd | sudo -S apt -qq install cron software-properties-common mariadb-client mariadb-server -y
echo $passwrd | sudo -S apt -qq install redis-server xvfb libfontconfig wkhtmltopdf -y
read -p "Let's configure your Mariadb server. Please hit Enter to start..."
echo $passwrd | sudo -S mysql_secure_installation <<EOF

y
y
$sql_passwrd
$sql_passwrd
y
n
y
y
EOF
touch mysql.sh
cat <<EOF > mysql.sh
#!/bin/bash
echo "\n\n\n[mysqld]\ncharacter-set-client-handshake = FALSE\ncharacter-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci\n\n\n[mysql]\ndefault-character-set = utf8mb4\n\n" >> /etc/mysql/my.cnf
rm /home/$USER/mysql.sh
EOF
echo $passwrd | sudo -S sh mysql.sh
echo $passwrd | sudo -S service mysql restart
read -p "Next, we'll install Node, NPM and Yarn. Please hit Enter..."
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
source ~/.profile
nvm install 18
echo $passwrd | sudo -S apt-get install npm -y
echo $passwrd | sudo -S npm install -g yarn
read -p "well, now we are ready to install frappe. Reay? :-) Hit Enter..."
echo $passwrd | sudo -S pip3 install frappe-bench
bench init --frappe-branch version-15 frappe-bench
cd frappe-bench/
chmod -R o+rx /home/$USER/
read -p "Frappe is initialized. Would you like to continue to create a site? (Y/n) " ans
if [ $ans = "n" ]; then exit 0; fi 
read -p "Please enter ne site name: " newSite
bench new-site $newSite
read -p "New site was created. Would you like to continue to install ERPNext? (Y/n)" ans
if [ $ans = "n" ]; then exit 0; fi 
bench use $newSite
bench get-app payments
bench get-app --branch version-15 erpnext
bench get-app hrms
bench install-app erpnext
bench install-app hrms
read -p "Good! Now, is your server ment for production? (Y/n) " ans
if [ $ans = "n" ]; then exit 0; fi 
bench enable-scheduler
bench set-maintenance-mode off
echo $passwrd | sudo -S bench setup production $USER
bench setup nginx
sudo supervisorctl restart all
sudo bench setup production $USER
cat << EOF
You can now go to your server [IP-address]:80 and you will have a fresh new installation of ERPNext ready to be configured!
If you are facing any issues with the ports, make sure to enable all the necessary ports on your firewall using the below commands:

  sudo ufw allow 22,25,143,80,443,3306,3022,8000/tcp
  sudo ufw enable
  
(Hint: you can open a new tty to run these two commands without stopping this script. (-; )
EOF

read -p "You can now configure SSL with a custom domain. Would you like to do so? (Y/n) " ans
if [ $ans = "n" ]; then exit 0; fi 
echo "First, make sure that there is an A record on your domain DNS pointing to the ERPNext server's IP address."
read -p "Then press enter to continue..."
bench config dns_multitenant on
read -p "Please enter your ERPNext server FQDN: " fqdn
bench setup add-domain $fqdn --site $newSite
bench setup nginx 
echo $passwrd | sudo -S service nginx reload
echo $passwrd | sudo -S snap install core
echo $passwrd | sudo -S snap refresh core
echo $passwrd | sudo -S snap install --classic certbot
echo $passwrd | sudo -S ln -s /snap/bin/certbot /usr/bin/certbot
echo $passwrd | sudo -S certbot --nginx
