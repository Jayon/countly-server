#!/bin/bash

#set -e

if [[ $EUID -ne 0 ]]; then
   echo "Please execute Countly installation script with a superuser..." 1>&2
   exit 1
fi

echo "
   ______                  __  __
  / ____/___  __  ______  / /_/ /_  __
 / /   / __ \/ / / / __ \/ __/ / / / /
/ /___/ /_/ / /_/ / / / / /_/ / /_/ /
\____/\____/\__,_/_/ /_/\__/_/\__, /
              http://count.ly/____/

"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#update package index
yum update

#yum -y install python-software-properties

#install node.js
yum -y groupinstall "Development Tools"
yum -y install screen
cd /usr/src
wget http://nodejs.org/dist/v0.10.4/node-v0.10.4.tar.gz
tar zxf node-v0.10.4.tar.gz
cd node-v0.10.4
./configure
make
make install

cd $DIR

#add nginx repo
cp nginx-countly.rep /etc/yum.repos.d/

#add mongodb repo
cp mongodb-10gen-countly.repo /etc/yum.repos.d/

#update once more after adding new repos
yum update

#install nginx
yum -y install nginx || (echo "Failed to install nginx." ; exit)

#install mongodb
yum -y install mongodb-org || (echo "Failed to install mongodb." ; exit)

#install supervisor
pip install supervisor || (echo "Failed to install supervisor." ; exit)

#install imagemagick
yum remove ImageMagick
yum install tcl-devel libpng-devel libjpeg-devel ghostscript-devel bzip2-devel freetype-devel libtiff-devel
mkdir /root/imagemagick
cd /root/imagemagick
wget ftp://ftp.imagemagick.org/pub/ImageMagick/ImageMagick.tar.gz
tar xzvf ImageMagick.tar.gz
cd ImageMagick-*
./configure --prefix=/usr/ --with-bzlib=yes --with-fontconfig=yes --with-freetype=yes --with-gslib=yes --with-gvc=yes --with-jpeg=yes --with-jp2=yes --with-png=yes --with-tiff=yes
make
make install

#install sendmail
yum install sendmail

yum groupinstall "Development Tools" || (echo "Failed to install build-essential." ; exit)

#install time module for node
( cd $DIR/../api ; npm install time )

#configure and start nginx
cp /etc/nginx/conf.d/default.conf $DIR/config/nginx.default.backup
cp $DIR/config/nginx.server.conf /etc/nginx/conf.d/default.conf
/etc/init.d/nginx start

cp $DIR/../frontend/express/public/javascripts/countly/countly.config.sample.js $DIR/../frontend/express/public/javascripts/countly/countly.config.js

#kill existing supervisor process
pkill -SIGTERM supervisord

#create supervisor upstart script
(cat $DIR/config/countly-supervisor.conf ; echo "exec /usr/bin/supervisord --nodaemon --configuration $DIR/config/supervisord.conf") > /etc/init/countly-supervisor.conf

#create api configuration file from sample
cp $DIR/../api/config.sample.js $DIR/../api/config.js

#create app configuration file from sample
cp $DIR/../frontend/express/config.sample.js $DIR/../frontend/express/config.js

#start mongod
service mongod start

#finally start countly api and dashboard
start countly-supervisor
