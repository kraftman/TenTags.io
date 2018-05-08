FROM redis:4.0
RUN apt-get update && apt-get install -y git build-essential
RUN mkdir /rebloom
RUN cd /rebloom && git clone git://github.com/RedisLabsModules/rebloom #redo
RUN cd /rebloom/rebloom && make

COPY redis.conf /data/redis.conf

CMD redis-server /data/redis.conf --loadmodule /rebloom/rebloom/rebloom.so 