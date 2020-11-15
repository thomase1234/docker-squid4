#!/bin/bash

PROXY_UID="${PROXY_UID:-13}"
PROXY_GID="${PROXY_GID:-13}"

usermod -u $PROXY_UID proxy
groupmod -g $PROXY_GID proxy

if [ -f /firstboot ]; then
    echo This is the firstboot. Checking if /etc/squid4/squid.conf exists.
    if [ ! -e /etc/squid4/squid.conf ]; then
        echo /etc/squid4/squid.conf doesn\'t exist. Copying config files. 
        cp -av /etc/squid4.orig/* /etc/squid4/
    fi
    rm /firstboot
fi

if [ ! -e /etc/squid4/squid.conf ]; then
    echo /etc/squid4/squid.conf doesn\'t exist: copying default. Please edit afterwards.
    cp /etc/squid4.orig/squid.conf /etc/squid4/squid.conf
fi

if [ ! -e /etc/squid4/cachemgr.conf ]; then
    echo /etc/squid4/cachemgr.conf doesn\'t exist: copying default. Please edit afterwards.
    cp /etc/squid4.orig/cachemgr.conf /etc/squid4/cachemgr.conf
fi

if [ ! -e /etc/squid4/errorpage.css ]; then
    echo /etc/squid4/errorpage.css doesn\'t exist: copying default. Please edit afterwards.
    cp /etc/squid4.orig/errorpage.css /etc/squid4/errorpage.css
fi

if [ ! -e /etc/squid4/mime.conf ]; then
    echo /etc/squid4/mime.conf doesn\'t exist: copying default. Please edit afterwards.
    cp /etc/squid4.orig/mime.conf /etc/squid4/mime.conf
fi

# Setup the ssl_cert directory
if [ ! -d /etc/squid4/ssl_cert ]; then
    mkdir /etc/squid4/ssl_cert
fi
chown -R proxy:proxy /etc/squid4
chmod 700 /etc/squid4/ssl_cert

# Setup the log directory
if [ ! -d /var/log/squid4 ]; then
    mkdir /var/log/squid4
fi
chown -R proxy:proxy /var/log/squid4

# Setup the squid cache directory
if [ ! -d /var/cache/squid4 ]; then
    mkdir -p /var/cache/squid4
fi
chown -R proxy: /var/cache/squid4
chmod -R 750 /var/cache/squid4

chown proxy: /dev/stdout
chown proxy: /dev/stderr

# Initialize the certificates database
/usr/libexec/security_file_certgen -c -s /var/spool/squid4/ssl_db -M 4MB
chown -R proxy: /var/spool/squid4/ssl_db

#ssl_crtd -c -s
#ssl_db

if [ ! -e /etc/squid4/squid.conf ]; then
    echo "ERROR: /etc/squid4/squid.conf does not exist. Squid will not work."
    exit 1
fi

# Build the configuration directories if needed
echo "Initializing cache..."
squid -z -N
echo "Initializing cache... DONE"

# Start squid normally
echo "Starting squid..."
squid -N 2>&1 &
echo "Starting squid... DONE"
PID=$!

# This construct allows signals to kill the container successfully.
trap "kill -TERM $(jobs -p)" INT TERM
wait $PID
wait $PID
exit $?
