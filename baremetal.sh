

# install build dependencies
 apt-get -qq update && apt-get -qqy install libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make curl git-core luarocks software-properties-common python-software-properties

 add-apt-repository ppa:maxmind/ppa && \
  apt-get update && \
  apt-get -y install libgeoip1 libgeoip-dev geoip-bin

# build/install OpenResty
SRC_DIR=/opt
OPENRESTY_VERSION=1.11.2.3
OPENRESTY_PREFIX=/opt/openresty
LAPIS_VERSION=1.5.1


# mkdir /geoip && cd /geoip && \
#  wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz && \
#  gunzip GeoIP.dat.gz && \
#  wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz && \
#  gunzip GeoLiteCity.dat.gz

 cd $SRC_DIR && curl -LOs https://openresty.org/download/openresty-$OPENRESTY_VERSION.tar.gz \
 && tar xzf openresty-$OPENRESTY_VERSION.tar.gz && cd openresty-$OPENRESTY_VERSION \
 && ./configure --prefix=$OPENRESTY_PREFIX \
 --with-luajit \
 --with-http_realip_module \
 --with-http_stub_status_module \
 --with-http_geoip_module \
 && make -j4 && make install && rm -rf openresty-$OPENRESTY_VERSION*

 luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis $LAPIS_VERSION && \
  luarocks install moonscript && \
  luarocks install lapis-console

cd $OPENRESTY_PREFIX/nginx/conf

LAPIS_OPENRESTY=$OPENRESTY_PREFIX/nginx/sbin/nginx

#my stuff

 apt-get update && apt-get install -y autossh uuid-dev #dnsmasq

 wget http://luarocks.github.io/luarocks/releases/luarocks-2.4.2.tar.gz
 tar -xvzf luarocks-2.4.2.tar.gz
 cd luarocks-2.4.2 && \
  ./configure && \
  make build &&\
  make install

 luarocks install date
# echo "\n\n# Docker extra config \nuser=root\naddn-hosts=/etc/hosts\n" >> /etc/dnsmasq.conf


cp GeoIP /geoip

 git clone https://github.com/duhoobo/lua-resty-smtp.git && \
cd lua-resty-smtp && \
make install

 apt-get update && apt-get install -y ca-certificates stunnel4

 luarocks install https://raw.githubusercontent.com/toritori0318/lua-resty-woothee/master/lua-resty-woothee-dev-1.rockspec && \
    luarocks install web_sanitize

#ENTRYPOINT ["/opt/openresty/nginx/conf/start.sh"]
