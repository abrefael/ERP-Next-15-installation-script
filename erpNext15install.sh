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
7. (Optional) Installing ERP-Next and additional custom applications.
8. (Optional) Making your server ready for production (with or with SSL conactivity).

This script is based on guide by shashank_shirke on the Frappe Forum:
https://discuss.frappe.io/t/guide-how-to-install-erpnext-v15-on-linux-ubuntu-step-by-step-instructions/111706

Good luck :-)

EOF
echo -e "Let's begin with your timezone.\nTake a look at your current date and time: $(date)\nIs it correct? [Y/n]"
read ans
if [ "$ans" = "n" ]; then
 echo -e "What is your time zone? (e.g.: Africa/Ceuta)\n (Hint: if you don't know your time zone identifier, checkout the following Wikipedia page:\nhttps://en.wikipedia.org/wiki/List_of_tz_database_time_zones)"
 read -p "" timez
 timedatectl set-timezone "$timez"
fi 
ans=""
read -rsp "Please enter sudo password:" passwrd
echo -e "\n"
read -rsp "Please enter mysql root password:" sql_passwrd
echo -e "\n\n"
read -p "Let's Update the system first. Please hit Enter to start..."
echo $passwrd | sudo -S apt-get update -y
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt-get upgrade -y
read -p "Now, we'll install some prerequisites. Please hit Enter to start..."
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt -qq install nano git curl -y
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt -qq install python3-dev python3.10-dev python3-pip -y
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt -qq install python3.10-venv -y
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt -qq install cron software-properties-common mariadb-client mariadb-server -y
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt -qq install supervisor redis-server xvfb libfontconfig wkhtmltopdf -y
MARKER_FILE=~/.MariaDB_handled.marker

if [ ! -f "$MARKER_FILE" ]; then
 read -p "Let's configure your Mariadb server. Please hit Enter to start..."
 echo $passwrd | sudo -S mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sql_passwrd';"
 echo $passwrd | sudo -S mysql -u root -p"$sql_passwrd" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sql_passwrd';"
 echo $passwrd | sudo -S mysql -u root -p"$sql_passwrd" -e "DELETE FROM mysql.user WHERE User='';"
 echo $passwrd | sudo -S mysql -u root -p"$sql_passwrd" -e "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
 echo $passwrd | sudo -S mysql -u root -p"$sql_passwrd" -e "FLUSH PRIVILEGES;"
 echo $passwrd | sudo -S bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF'

 echo $passwrd | sudo -S service mysql restart
 touch "$MARKER_FILE"
fi
read -p "Next, we'll install Node, NPM and Yarn. Please hit Enter..."
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 18
echo $passwrd | sudo -S NEEDRESTART_MODE=a apt-get install npm -y
echo $passwrd | sudo -S npm install -g yarn
read -p "well, now we are ready to install frappe. Ready? :-) Hit Enter..."
echo $passwrd | sudo -S pip3 install frappe-bench
bench init --frappe-branch version-15 frappe-bench
chmod -R o+rx .
cd frappe-bench/
read -p "Frappe is initialized. Would you like to continue to create a site? (Y/n) " ans
if [ $ans = "n" ]; then exit 0; fi 
ans=""
read -p "Please enter new site name: " newSite
bench new-site $newSite --db-root-password $sql_passwrd
bench use $newSite
echo -e "If you wish to install a custom apps, enter it's URIs.\nStarting with the first:\n"
while read URI; do
 if [ "$URI" = "" ]; then
 break
 fi
 IFS='/' read -a array <<< "$URI"
 bench get-app --resolve-deps $URI
 app_name=${array[-1]}
 if [[ $app_name == *".git" ]]; then
 bench install-app "${app_name:0:-4}";
 else 
 bench install-app "${app_name}";
 fi
 URI=""
 echo -e "Any more apps? Enter another URI (otherwise hit Enter):\n"
done
read -p "Would you like to continue and install ERPNext? (y/N) " ans
if [ $ans = "y" ]; then 
  ans=""
  bench get-app payments
  bench get-app --branch version-15 erpnext
  bench get-app hrms
  bench install-app erpnext
  bench install-app hrms
fi
read -p "Good! Now, is your server ment for production? (Y/n) " ans
if [ $ans = "n" ]; then exit 0; fi 
ans=""
echo $passwrd | sudo -S sed -i -e 's/include:/include_tasks:/g' /usr/local/lib/python3.10/dist-packages/bench/playbooks/roles/mariadb/tasks/main.yml
yes | sudo bench setup production $USER
FILE="/etc/supervisor/supervisord.conf"
SEARCH_PATTERN="chown=$USER:$USER"
if grep -q "$SEARCH_PATTERN" "$FILE"; then
 echo $passwrd | sudo -S sed -i "/chown=.*/c $SEARCH_PATTERN" "$FILE"
else
 echo $passwrd | sudo -S sed -i "5a $SEARCH_PATTERN" "$FILE"
fi
echo $passwrd | sudo -S service supervisor restart
yes | sudo bench setup production $USER
bench --site $newSite scheduler enable
bench --site $newSite scheduler resume
bench setup socketio
yes | bench setup supervisor
bench setup redis
echo $passwrd | sudo -S supervisorctl reload
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
sudo service nginx reload
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx
