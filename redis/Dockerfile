FROM ubuntu

RUN apt-get update

#RUN groupadd -r redis && useradd -r -g redis redis

RUN apt-get install -y gcc cmake wget

RUN wget http://download.redis.io/releases/redis-3.2.1.tar.gz && \
    tar xzf redis-3.2.1.tar.gz && \
    cd redis-3.2.1 && \
    make && \
    make install


RUN mkdir /data
VOLUME /data
COPY redis.conf /data/redis.conf
CMD [ "redis-server", "/data/redis.conf" ]
