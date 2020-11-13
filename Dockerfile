ARG DOCKER_PREFIX=

FROM ${DOCKER_PREFIX}ubuntu:focal

ARG TRUST_CERT=

ARG URL_DOH=https://github.com/wrouesnel/dns-over-https-proxy/releases/download/v0.0.2/dns-over-https-proxy_v0.0.2_linux-amd64.tar.gz

ARG CONCURRENCY=4

ARG SQUID_VERSION=4.13

ARG PROXYCHAINS_COMMITTISH=7a233fb1f05bcbf3d7f5c91658932261de1e13cb

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
# Download p2cli dependency
    wget -O /usr/local/bin/p2 \
    https://github.com/wrouesnel/p2cli/releases/download/r1/p2 && \
    chmod +x /usr/local/bin/p2 && \
    git clone https://github.com/rofl0r/proxychains-ng.git /src/proxychains-ng && \
    cd /src/proxychains-ng && \
    git checkout $PROXYCHAINS_COMMITTISH && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j$CONCURRENCY && make install  && \
    wget -O /tmp/doh.tgz $URL_DOH && \
    tar -xvvf /tmp/doh.tgz --strip-components=1 -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/dns-over-https-proxy && \
    cd / && rm -rf /src && rm /tmp/doh.tgz && \
# remove buildtime dependencies
    apt-get remove -y nano xz-utils libssl-dev squid-build-deps devscripts equivs git && \
    apt-get autoremove -y && \
# install runtime dependencies
    apt-get install --no-install-recommends -y libxml2 libexpat1 libgssapi-krb5-2 libcap2 libnetfilter-conntrack3 libltdl7 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY squid.conf.p2 /squid.conf.p2
COPY squid.bsh /squid.bsh

# Configuration environment
ENV HTTP_PORT=3128 \
    ICP_PORT= \
    HTCP_PORT= \
    MITM_PROXY= \
    MITM_CERT= \
    MITM_KEY= \
    VISIBLE_HOSTNAME=docker-squid4 \
    MAX_CACHE_SIZE=40000 \
    MAX_OBJECT_SIZE="1536 MB" \
    MEM_CACHE_SIZE="128 MB" \
    DNS_OVER_HTTPS_LISTEN_ADDR="127.0.0.153:53" \
    DNS_OVER_HTTPS_SERVER="https://dns.google.com/resolve" \
    DNS_OVER_HTTPS_NO_FALLTHROUGH="" \
    DNS_OVER_HTTPS_FALLTHROUGH_STATUSES=NXDOMAIN \
    DNS_OVER_HTTPS_PREFIX_SERVER= \
    DNS_OVER_HTTPS_SUFFIX_SERVER=

EXPOSE 3128

ENTRYPOINT [ "/squid.bsh" ]
