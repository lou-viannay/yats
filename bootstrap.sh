#!/usr/bin/env bash
USERNAME=`id -un`
GROUPNAME=`id -gn`
BASE_DIR=`realpath .`

VERSION=$(sed 's/\..*//' /etc/debian_version)
sites=`python3 -c "import site; print(site.getsitepackages()[0])"`
ret_sock=`grep -ir "TCPSocket" /etc/clamav/clamd.conf`
ret_addr=`grep -ir "TCPAddr" /etc/clamav/clamd.conf`
sudo bash<<__ENDSCRIPT__

# debian packages
apt-get update
apt-get install -y memcached locales-all libjpeg62-turbo libjpeg-dev libpng-dev screen apache2 sqlite3 gettext ant wget ntp clamav clamav-daemon libreoffice
apt-get install -y python3 python3-dev python3-memcache python3-httplib2 python3-wand libapache2-mod-wsgi-py3 python3-xapian-haystack

wget https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py

# python modules
ln -fs ${BASE_DIR}/modules/yats $sites 2>/dev/null
ln -fs ${BASE_DIR}/modules/bootstrap_toolkit $sites 2>/dev/null
ln -fs ${BASE_DIR}/modules/graph $sites 2>/dev/null
ln -fs ${BASE_DIR}/modules/simple_sso $sites 2>/dev/null
#ln -fs /vagrant_modules/djradicale $sites 2>/dev/null
#ln -fs /vagrant_modules/pyxmpp2 $sites 2>/dev/null
#ln -fs /vagrant_modules/radicale $sites 2>/dev/null

pip3 install -r vagrant/requirements.txt
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
chown root:$GROUPNAME /var/web/yats/static
chmod go+w /var/web/yats/static

ln -fs ${BASE_DIR}/sites/web /var/web/yats/web

mkdir -p /var/web/yats/files
chown root:$GROUPNAME /var/web/yats/files
chmod go+w /var/web/yats/files

mkdir -p /var/web/yats/logs
touch /var/web/yats/logs/django_request.log
chown root:$GROUPNAME /var/web/yats/logs/django_request.log
chmod go+w /var/web/yats/logs/django_request.log

ln -fs ${BASE_DIR}/sites/caldav /var/web/yats/caldav

# yats config
mkdir -p /usr/local/yats/config
ln -fs ${BASE_DIR}/vagrant/web.ini /usr/local/yats/config/web.ini

# yats db
mkdir -p /var/web/yats/db
chown root:$GROUPNAME /var/web/yats/db
chmod go+w /var/web/yats/db

# yats index
mkdir -p /var/web/yats/index
chown root:vagrant /var/web/yats/index
chmod go+w /var/web/yats/index

cd /var/web/yats/web/

touch /var/web/yats/db/yats2.sqlite
chown root:$GROUPNAME /var/web/yats/db/yats2.sqlite
chmod go+w /var/web/yats/db/yats2.sqlite
python3 manage.py migrate
python3 manage.py createsuperuser --username root --email root@localhost --noinput
python3 manage.py loaddata ${BASE_DIR}/vagrant/init_db.json
pygmentize -S default -f html -a .codehilite > ${BASE_DIR}/modules/yats/static/pygments.css
python3 manage.py collectstatic  -l --noinput

# apache config
a2enmod ssl
mkdir -p /etc/apache2/certs
cd /etc/apache2/certs
openssl genrsa -out dev.yats.net.key 2048
openssl req -new -x509 -key dev.yats.net.key -out dev.yats.net.cert -days 3650 -subj /CN=dev.yats.net
cp ${BASE_DIR}/vagrant/yats.apache /etc/apache2/sites-available/yats.conf
a2dissite default
a2dissite 000-default
a2ensite yats
apache2ctl restart

# testticket via API
python3 ${BASE_DIR}/test/api_simple_create.py

# rebuid Index
python3 manage.py clear_index --noinput
python3 manage.py update_index --noinput

# deb upgrade
apt-get -y upgrade &

# running ant and ignore error
cd ${BASE_DIR}
ant ci18n

timedatectl set-ntp true

echo "open http://192.168.33.11 with user: admin password: admin"

__ENDSCRIPT__