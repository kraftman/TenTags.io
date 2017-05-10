# latest official node image

FROM kraftman/docker-node-onbuild
#
# MAINTAINER Jonathan Foster <jxf9099@rit.edu>

# use nodemon for development
#
# WORKDIR /node

#
# RUN npm install -g nodemon && \
#     npm install -g express-generator && \
#     npm install -g express && \
#     npm install -g aws-sdk
#
# RUN apt-get update && apt-get install -y python make g++ build-essential
#
# RUN npm install -g emailjs
# RUN npm install -g passwordless
# RUN npm install -g node-gyp
# RUN npm install -g node-pre-gyp
# RUN npm install -g bcrypt
# RUN npm install -g passwordless-redisstore
# # use cached layer for node modules
#ADD package.json /tmp/package.json
#RUN cd /tmp && npm install
#RUN mkdir -p /usr/src && cp -a /tmp/node_modules /usr/src/

# add project files
#WORKDIR /usr/src
#ADD . /usr/src
RUN npm install -g webpack webpack-dev-server

RUN npm install -g nodemon


CMD ["nodemon", "server.js"]
