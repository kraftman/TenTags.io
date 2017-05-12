FROM erikcw/lapis:latest

RUN apt-get update && apt-get install -y autossh uuid-dev #dnsmasq

RUN wget http://luarocks.github.io/luarocks/releases/luarocks-2.4.2.tar.gz
RUN tar -xvzf luarocks-2.4.2.tar.gz
RUN cd luarocks-2.4.2 && \
  ./configure && \
  make build &&\
  make install

RUN luarocks install date
#RUN echo "\n\n# Docker extra config \nuser=root\naddn-hosts=/etc/hosts\n" >> /etc/dnsmasq.conf


RUN git clone https://github.com/duhoobo/lua-resty-smtp.git && \
cd lua-resty-smtp && \
make install

RUN apt-get update && apt-get install ca-certificates

RUN luarocks install https://raw.githubusercontent.com/toritori0318/lua-resty-woothee/master/lua-resty-woothee-dev-1.rockspec
