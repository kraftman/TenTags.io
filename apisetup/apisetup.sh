apt-get install -y lua5.1 libpcre3 libpcre3-dev uuid-dev
apt-get install -y libreadline-dev libncurses5-dev libpcre3-dev \
    libssl-dev perl make build-essential autossh
apt-get install -y luarocks

wget https://openresty.org/download/ngx_openresty-1.9.3.1.tar.gz
tar xzvf ngx_openresty-1.9.3.1.tar.gz
cd ngx_openresty-1.9.3.1
./configure
make
make install


luarocks install luasec OPENSSL_LIBDIR=/usr/lib/x86_64-linux-gnu/
luarocks install lapis
luarocks install magick

git clone https://github.com/duhoobo/lua-resty-smtp.git
cd lua-resty-smtp
make install
cd ..

iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 10050 -j ACCEPT

wget http://repo.zabbix.com/zabbix/2.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_2.2-1+precise_all.deb
dpkg -i zabbix-release_2.2-1+precise_all.deb
apt-get update
apt-get install zabbix-agent

cp taggr/apisetup/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf
service zabbix-agent restart

#also need to setup on startup
autossh -f -M 0 -N -L 6379:localhost:6379 -o "ServerAliveInterval 60" \
  -o "ServerAliveCountMax 3" -o "StrictHostKeyChecking=no" -o "BatchMode=yes" \
  -i /root/.ssh/id_rsa root@master.filtta.com
