ARG DOCKER_PREFIX=

FROM ${DOCKER_PREFIX}ubuntu:focal

LABEL maintainer="Thomas Elsen <thomas.elsen@rivy.org>"

ARG TRUST_CERT=

ARG CONCURRENCY=4

ARG SQUID_VERSION=4.13

ARG DEBIAN_FRONTEND=noninteractive

RUN if [ ! -z "$TRUST_CERT" ]; then \
    echo "$TRUST_CERT" > /usr/local/share/ca-certificates/build-trust.crt ; \
    update-ca-certificates ; \
    fi && \
    cat /etc/apt/sources.list | grep -v '^#' | sed /^$/d > sources.tmp.1 && \
    cat /etc/apt/sources.list | sed s/deb\ /deb-src\ /g | grep -v '^#' | sed /^$/d > sources.tmp.2 && \
    cat sources.tmp.1 sources.tmp.2 | sort -u > /etc/apt/sources.list && \
    rm -f sources.tmp.1 sources.tmp.2 && \
    apt-get update && \
    apt-get install -y devscripts equivs git wget xz-utils libssl-dev nano && \ 
    mk-build-deps squid --install -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y' && \
    mkdir /src && \
    cd /src && \
    wget http://www.squid-cache.org/Versions/v4/squid-$SQUID_VERSION.tar.xz && \
    mkdir squid && \
    tar -C squid --strip-components=1 -xvf squid-$SQUID_VERSION.tar.xz && \
    cd /src/squid && \
    ./configure \
        --prefix=/usr \
        --datadir=/usr/share/squid4 \
        --sysconfdir=/etc/squid4 \
        --localstatedir=/var \
        --mandir=/usr/share/man \
        --enable-inline \
        --enable-async-io=8 \
        --enable-storeio="ufs,aufs,diskd,rock" \
        --enable-removal-policies="lru,heap" \
        --enable-delay-pools \
        --enable-cache-digests \
        --enable-underscores \
        --enable-icap-client \
        --enable-follow-x-forwarded-for \
        --enable-auth-basic="DB,fake,getpwnam,LDAP,NCSA,NIS,PAM,POP3,RADIUS,SASL,SMB" \
        --enable-auth-digest="file,LDAP" \
        --enable-auth-negotiate="kerberos,wrapper" \
        --enable-auth-ntlm="fake" \
        --enable-external-acl-helpers="file_userip,kerberos_ldap_group,LDAP_group,session,SQL_session,unix_group,wbinfo_group" \
        --enable-url-rewrite-helpers="fake" \
        --enable-eui \
        --enable-esi \
        --enable-icmp \
        --enable-zph-qos \
        --with-openssl \
        --enable-ssl \
        --enable-ssl-crtd \
        --disable-translation \
        --with-swapdir=/var/spool/squid4 \
        --with-logdir=/var/log/squid4 \
        --with-pidfile=/var/run/squid4.pid \
        --with-filedescriptors=65536 \
        --with-large-files \
        --with-default-user=proxy \
        --disable-arch-native && \
    make -j$CONCURRENCY && \
    make install && \
    chmod +s /usr/libexec/pinger && \
    cd / && rm -rf /src && \
    # remove buildtime dependencies
    apt-get remove -y nano xz-utils libssl-dev squid-build-deps devscripts equivs git && \
    apt-get autoremove -y && \
    # install runtime dependencies
    apt-get install --no-install-recommends -y libxml2 libexpat1 libgssapi-krb5-2 libcap2 libnetfilter-conntrack3 libltdl7 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN cp -av /etc/squid4 /etc/squid4.orig && \
    rm -rf /etc/squid4/* && \
    touch /firstboot

COPY entrypoint.sh /entrypoint.sh

# Configuration environment
ENV PROXY_UID=13 \
    PROXY_GID=13

EXPOSE 3128

ENTRYPOINT [ "/entrypoint.sh" ]
