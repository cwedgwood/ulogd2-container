
FROM debian:bullseye-slim as common
# Useful common things; be minimalist then cleanup afterwards to avoid large layers
RUN ( apt-get update && apt-get install --no-install-recommends -y iproute2 jq time rsyslog less strace psmisc procps nvi pbzip2 && apt-get clean && find /var/lib/apt/ -type f -print0 | xargs -r0 rm -v )

FROM common as build
# Recompliation (less common); don't need to be overly conservative
RUN ( apt-get update && apt-get install -y git make autoconf automake libtool pkg-config libjansson-dev )

WORKDIR /build

# libmnl:		   libmnl-1.0.4
RUN git clone git://git.netfilter.org/libmnl
RUN ( cd libmnl && git checkout libmnl-1.0.4 && autoreconf -fi && PKG_CONFIG_PATH=/opt/netfilter/lib/pkgconfig ./configure --prefix=/opt/netfilter/ --enable-static )
RUN ( cd libmnl && time make -j12 && make install )

# libnfnetlink:		   libnfnetlink-1.0.1
RUN git clone git://git.netfilter.org/libnfnetlink
RUN ( cd libnfnetlink && git checkout libnfnetlink-1.0.1 && autoreconf -fi && PKG_CONFIG_PATH=/opt/netfilter/lib/pkgconfig ./configure --prefix=/opt/netfilter/ --enable-static )
RUN ( cd libnfnetlink && time make -j12 && make install )

# libnetfilter_conntrack:  libnetfilter_conntrack-1.0.8-25-gdbfa07f
RUN git clone git://git.netfilter.org/libnetfilter_conntrack
RUN ( cd libnetfilter_conntrack && git checkout libnetfilter_conntrack-1.0.8 && autoreconf -fi && PKG_CONFIG_PATH=/opt/netfilter/lib/pkgconfig ./configure --prefix=/opt/netfilter/ --enable-static )
RUN ( cd libnetfilter_conntrack && time make -j12 && make install )

# libnetfilter_log:        libnetfilter_log-1.0.2-1-ge920203
RUN git clone git://git.netfilter.org/libnetfilter_log
RUN ( cd libnetfilter_log && git checkout libnetfilter_log-1.0.2 && autoreconf -fi && PKG_CONFIG_PATH=/opt/netfilter/lib/pkgconfig ./configure --prefix=/opt/netfilter/ --enable-static )
RUN ( cd libnetfilter_log && time make -j12 && make install )

# libnetfilter_acct:       libnetfilter_acct-1.0.3
RUN git clone git://git.netfilter.org/libnetfilter_acct
RUN ( cd libnetfilter_acct && git checkout libnetfilter_acct-1.0.3 && autoreconf -fi && PKG_CONFIG_PATH=/opt/netfilter/lib/pkgconfig ./configure --prefix=/opt/netfilter/ --enable-static )
RUN ( cd libnetfilter_acct && time make -j12 && make install )

# ulogd2:                  ulogd-2.0.7-33-ga8cedca
RUN git clone git://git.netfilter.org/ulogd2
RUN ( cd ulogd2 && git checkout 5f9628c9273815b6e560603427fe86118e7cb5bb && autoreconf -fi && PKG_CONFIG_PATH=/opt/netfilter/lib/pkgconfig ./configure --prefix=/opt/netfilter/ --enable-static )
RUN ( cd ulogd2 && time make -j12 && make install )

# cleanup dev/installed stuff that we don't need for running the final
# binary
RUN rm -r /opt/netfilter/include/
RUN rm -r  /opt/netfilter/lib/pkgconfig/
RUN rm -r /opt/netfilter/lib/*a /opt/netfilter/lib/ulogd/*a
RUN strip /opt/netfilter/lib/*so /opt/netfilter/lib/ulogd/*so

# Show what we ended up with
RUN find /opt/netfilter/ -type f -ls


# create a new layer with minimally what we need and copy over only
# what we need

FROM common AS deployable

COPY --from=build /opt/netfilter/   /opt/netfilter/
# hacky but whatever, this avoids apt and the like in a minimalist
# sense for now
COPY --from=build /usr/lib/x86_64-linux-gnu/libjansson.so.4* /usr/lib/x86_64-linux-gnu/

# to run tests we need these
RUN mkdir -p /opt/netfilter/etc/
