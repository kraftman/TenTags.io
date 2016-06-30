FROM ubuntu:14.04

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
# build imagemagick
RUN wget http://www.imagemagick.org/download/ImageMagick.tar.gz && \
  tar xvzf ImageMagick.tar.gz && \
  cd ImageMagick-7.0.2-1 && \
  ./configure && \
  make && \
  make install && \
  cd .. && \
  ldconfig /usr/local/lib

#temporary solution to lua-imagick grabbing the wrong files
#RUN mv /usr/lib/x86_64-linux-gnu/libMagickWand.a /usr/lib/x86_64-linux-gnu/libMagickWand_old.a && \
#    mv /usr/lib/x86_64-linux-gnu/libMagickWand.so /usr/lib/x86_64-linux-gnu/libMagickWand_old.so

# build lua-imagick
RUN git clone https://github.com/isage/lua-imagick.git && \
  cd lua-imagick && \
  mkdir build && \
  cd build && \
  cmake .. && \
  make && \
  sudo make install

RUN luarocks install --server=http://luarocks.org/dev giflib && \
    luarocks install redis-lua && \
    luarocks install luasocket && \
    luarocks install magick


RUN mkdir /lua
VOLUME /lua
CMD [ "lua", "lua/imgconverter.lua" ]
