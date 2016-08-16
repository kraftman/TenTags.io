FROM erikcw/lapis:latest

RUN apt-get install -y autossh uuid-dev #dnsmasq
RUN luarocks install lua-resty-redis-connector
#RUN echo "\n\n# Docker extra config \nuser=root\naddn-hosts=/etc/hosts\n" >> /etc/dnsmasq.conf


RUN git clone https://github.com/duhoobo/lua-resty-smtp.git && \
cd lua-resty-smtp && \
make install && \
cd .. \
