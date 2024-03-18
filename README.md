# ERP-Next-15-installation-script

In order to use this you will need to have a clean install of Ubuntu server 22.04. You need to log in to the server with a sudoer account and perform the following:

```
sudo adduser [frappe-user]
usermod -aG sudo [frappe-user]
```

and then log in using the [frapp-user] above. the rest is to execute:

```
sudo chmod +x erpNext15install.sh
./frappe_install.sh
```

And follow the instructions. You will be prompt to supply your sudo password (the password that you gave your [frappe-user]) and a required password for your mariadb server root acount (select something complex enough, but a password you can remember...).

When you finished installing you will be able to continue with site creation, ERPNext15 install, and going production.

Good luck! :-)
