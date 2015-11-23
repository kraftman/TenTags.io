apt-get install -y lua5.1 libpcre3 libpcre3-dev uuid-dev
apt-get install -y libreadline-dev libncurses5-dev libpcre3-dev \
    libssl-dev perl make build-essential

wget https://openresty.org/download/ngx_openresty-1.9.3.1.tar.gz
tar xzvf ngx_openresty-1.9.3.1.tar.gz
cd ngx_openresty-1.9.3.1
./configure
make
make install


luarocks install luasec OPENSSL_LIBDIR=/usr/lib/x86_64-linux-gnu/
luarocks install lapis
luarocks install magick
