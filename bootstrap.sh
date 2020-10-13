#!/usr/bin/env bash
USERNAME=`id -un`
GROUPNAME=`id -gn`
BASE_DIR=`realpath .`
IP_ADDRESS=`ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 | awk '{ print $2 }'`

VERSION=$(sed 's/\..*//' /etc/debian_version)
sites=`python3 -c "import site; print(site.getsitepackages()[0])"`
sudo bash<<INSTALL_PART
# debian packages
apt update
apt install -y memcached locales-all libjpeg62 libjpeg-dev libpng-dev screen sqlite3 gettext ant wget ntp clamav clamav-daemon libreoffice
apt install -y python3 python3-dev python3-memcache python3-httplib2 python3-wand python3-xapian-haystack
apt install -y python3-pip
apt install -y nginx supervisor


# setup supervisor
cp ${BASE_DIR}/nginx/supervisor.conf /etc/nginx/conf.d/
sed -i 's/SERVER_NAME_OR_IP_ADDRESS/${IP_ADDRESS}/g' /etc/nginx/conf.d/supervisor.conf
sed -i 's/chmod=0700/chmod=777/g' /etc/supervisor/supervisord.conf
INSTALL_PART

ret_sock=`grep -ir "TCPSocket" /etc/clamav/clamd.conf`
ret_addr=`grep -ir "TCPAddr" /etc/clamav/clamd.conf`

sudo bash<<__ENDSCRIPT__


# python modules
ln -fs ${BASE_DIR}/modules/yats $sites 2>/dev/null
ln -fs ${BASE_DIR}/modules/bootstrap_toolkit $sites 2>/dev/null
ln -fs ${BASE_DIR}/modules/graph $sites 2>/dev/null
ln -fs ${BASE_DIR}/modules/simple_sso $sites 2>/dev/null
#ln -fs /vagrant_modules/djradicale $sites 2>/dev/null
#ln -fs /vagrant_modules/pyxmpp2 $sites 2>/dev/null
#ln -fs /vagrant_modules/radicale $sites 2>/dev/null

pip3 install git+https://github.com/django-haystack/django-haystack.git
pip3 install gunicorn 

pip3 install -r ${BASE_DIR}/vagrant/requirements.txt
#/vagrant/install_xapian.sh

# clamav config
if [ "" = "$ret_sock" ]; then
echo "TCPSocket 3310" >> /etc/clamav/clamd.conf
fi
if [ "" = "$ret_addr" ]; then
echo "TCPAddr 127.0.0.1" >> /etc/clamav/clamd.conf
fi
echo "ListenStream=127.0.0.1:3310" >> /etc/systemd/system/clamav-daemon.socket.d/extend.conf
systemctl --system daemon-reload
systemctl restart clamav-daemon.socket
systemctl restart clamav-daemon.service
freshclam&

# yats web
mkdir -p /var/web/yats
mkdir -p /var/web/yats/static
chown $USERNAME:$GROUPNAME /var/web/yats/static
chmod go+w /var/web/yats/static

ln -fs ${BASE_DIR}/sites/web /var/web/yats/web

mkdir -p /var/web/yats/files
chown $USERNAME:$GROUPNAME /var/web/yats/files
chmod go+w /var/web/yats/files

mkdir -p /var/web/yats/logs
touch /var/web/yats/logs/django_request.log
chown $USERNAME:$GROUPNAME /var/web/yats/logs/django_request.log
chmod go+w /var/web/yats/logs/django_request.log

ln -fs ${BASE_DIR}/sites/caldav /var/web/yats/caldav

# yats config
mkdir -p /usr/local/yats/config
ln -fs ${BASE_DIR}/vagrant/web.ini /usr/local/yats/config/web.ini

# yats db
mkdir -p /var/web/yats/db
chown $USERNAME:$GROUPNAME /var/web/yats/db
chmod go+w /var/web/yats/db

# yats index
mkdir -p /var/web/yats/index
chown $USERNAME:$GROUPNAME /var/web/yats/index
chmod go+w /var/web/yats/index

cd /var/web/yats/web/

touch /var/web/yats/db/yats2.sqlite
chown $USERNAME:$GROUPNAME /var/web/yats/db/yats2.sqlite
chmod go+w /var/web/yats/db/yats2.sqlite
python3 manage.py migrate
python3 manage.py createsuperuser --username root --email root@localhost --noinput
python3 manage.py loaddata ${BASE_DIR}/vagrant/init_db.json
pygmentize -S default -f html -a .codehilite > ${BASE_DIR}/modules/yats/static/pygments.css
python3 manage.py collectstatic  -l --noinput

# apache config
# a2enmod ssl
# mkdir -p /etc/apache2/certs
# cd /etc/apache2/certs
# openssl genrsa -out dev.yats.net.key 2048
# openssl req -new -x509 -key dev.yats.net.key -out dev.yats.net.cert -days 3650 -subj /CN=dev.yats.net
# cp ${BASE_DIR}/vagrant/yats.apache /etc/apache2/sites-available/yats.conf
# a2dissite default
# a2dissite 000-default
# a2ensite yats
# apache2ctl restart

# testticket via API
python3 ${BASE_DIR}/test/api_simple_create.py

# rebuid Index
python3 manage.py clear_index --noinput
python3 manage.py update_index 

# deb upgrade
apt-get -y upgrade &

# running ant and ignore error
# cd ${BASE_DIR}
# ant ci18n

timedatectl set-ntp true

# echo "open http://192.168.33.11 with user: admin password: admin"

__ENDSCRIPT__