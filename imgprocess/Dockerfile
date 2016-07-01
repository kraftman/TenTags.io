FROM ubuntu:16.04

RUN apt-get update #redo

#lua and stuff to build imagemagick/lua-imagemagick
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    lua5.1 \
    luajit \
    cmake \
    luajit-5.1-dev \
    wget build-essential \
    ghostscript \
    luarocks



RUN apt-get install -y libmagickwand-dev
RUN luarocks install magick

RUN luarocks install --server=http://luarocks.org/dev giflib && \
    luarocks install redis-lua && \
    luarocks install luasocket && \
    luarocks install magick

RUN apt-get build-dep -y giflib-dbg

RUN apt-get install -y curl
ENV GIFLIB_VERSION 5.1.4
WORKDIR /tmp
RUN curl -sOL http://prdownloads.sourceforge.net/giflib/giflib-${GIFLIB_VERSION}.tar.gz \
	&& tar xzf giflib-${GIFLIB_VERSION}.tar.gz \
	&& cd giflib-${GIFLIB_VERSION} \
	&& ./configure --prefix=${DEST} --enable-shared --disable-static \
	&& make \
	&& make install-strip


RUN luarocks install --server=http://luarocks.org/dev giflib



RUN mkdir -p /var/www && mkdir /lua
WORKDIR /lua
VOLUME /var/www
CMD [ "luajit", "imgconverter.lua" ]
