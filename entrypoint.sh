#!/bin/bash

PROXY_UID="${PROXY_UID:-13}"
PROXY_GID="${PROXY_GID:-13}"

usermod -u $PROXY_UID proxy
groupmod -g $PROXY_GID proxy

if [ -f /firstboot ]; then
    echo This is the firstboot. Creating default config dir.
    cp -av /etc/squid4.orig/* /etc/squid4/
    rm /firstboot
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

if [ ! -z $MITM_PROXY ]; then
    if [ ! -z $MITM_KEY ]; then
        echo "Copying $MITM_KEY as MITM key..."
        cp $MITM_KEY /etc/squid4/ssl_cert/mitm.pem
        chown root:proxy /etc/squid4/ssl_cert/mitm.pem
    fi

    if [ ! -z $MITM_CERT ]; then
        echo "Copying $MITM_CERT as MITM CA..."
        cp $MITM_CERT /etc/squid4/ssl_cert/mitm.crt
        chown root:proxy /etc/squid4/ssl_cert/mitm.crt
    fi

    if [ -z $MITM_CERT ] || [ -z $MITM_KEY ]; then
        echo "Must specify $MITM_CERT AND $MITM_KEY." 1>&2
        exit 1
    fi
fi

chown proxy: /dev/stdout
chown proxy: /dev/stderr

# Initialize the certificates database
/usr/libexec/security_file_certgen -c -s /var/spool/squid4/ssl_db -M 4MB
chown -R proxy: /var/spool/squid4/ssl_db

#ssl_crtd -c -s
#ssl_db

# Set the configuration
echo "/etc/squid4/squid.conf: CONFIGURATION TEMPLATING IS DISABLED."


if [ ! -e /etc/squid4/squid.conf ]; then
    echo "ERROR: /etc/squid4/squid.conf does not exist. Squid will not work."
    exit 1
fi

# Build the configuration directories if needed
squid -z -N

# Start squid normally
squid -N 2>&1 &
PID=$!

# This construct allows signals to kill the container successfully.
trap "kill -TERM $(jobs -p)" INT TERM
wait $PID
wait $PID
exit $?
