FROM ubuntu:14.04
FROM python:3


RUN curl -sL https://deb.nodesource.com/setup_6.x | bash
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common python-software-properties
#RUN add-apt-repository ppa:chris-lea/redis-server

ENV DEBIAN_FRONTEND=noninteractive

MAINTAINER Alexander Swensen <alex.swensen@gmail.com>

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install Required Packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y python-pip build-essential python-dev mysql-server nodejs nginx python-software-properties software-properties-common


# first create user and group for all the X Window stuff
# required to do this first so have consistent uid/gid between server and client container
RUN addgroup --system xusers \
  && adduser \
			--home /home/xuser \
			--disabled-password \
			--shell /bin/bash \
			--gecos "user for running X Window stuff" \
			--ingroup xusers \
			--quiet \
			xuser

# Install xvfb as X-Server and x11vnc as VNC-Server
RUN apt-get update && apt-get install -y --no-install-recommends \
				xvfb \
				xauth \
				x11vnc \
				x11-utils \
				x11-xserver-utils \
		&& rm -rf /var/lib/apt/lists/*

# create or use the volume depending on how container is run
# ensure that server and client can access the cookie
RUN mkdir -p /Xauthority && chown -R xuser:xusers /Xauthority
VOLUME /Xauthority

RUN set -xe \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl socat \
    && apt-get install -y --no-install-recommends xvfb x11vnc fluxbox xterm \
    && apt-get install -y --no-install-recommends sudo \
    && apt-get install -y --no-install-recommends supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN set -xe \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

#========================================
# Add normal user with passwordless sudo
#========================================

# install NVM
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.5/install.sh | bash

ENV NODE_VERSION 6.11.1

# Install a version of node & latest npm
RUN source /root/.bashrc && \
    cd /root && \
    nvm install $NODE_VERSION && \
    npm install -g npm@latest

# Install latest npm
RUN npm install -g npm@latest

# Install Redis from source
ENV REDIS_VERSION 4.0.2
ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz
ENV REDIS_DOWNLOAD_SHA1 d2588569a35531fcdf03ff05cf0e16e381bc278f

RUN buildDeps='gcc libc6-dev make' \
    && set -x \
    && apt-get update && apt-get install -y $buildDeps --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" \
    && echo "$REDIS_DOWNLOAD_SHA1 *redis.tar.gz" | sha1sum -c - \
    && mkdir -p /usr/src/redis \
    && tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 \
    && rm redis.tar.gz \
    && make -C /usr/src/redis \
    && make -C /usr/src/redis install \
    && rm -r /usr/src/redis

# VIRTUALENV - Set up virtualenv and virtualenvwrapper, can use whichever you prefer
RUN pip install virtualenv virtualenvwrapper


# Install Google Chrome
#RUN apt-get update && apt-get install -y gconf-service libasound2 libatk1.0-0 libcups2 libgconf-2-4 libgtk-3-0 libnspr4 libx11-xcb1 libxcomposite1 fonts-liberation libappindicator1 libnss3 xdg-utils
#RUN wget https://raw.githubusercontent.com/webnicer/chrome-downloads/master/x64.deb/google-chrome-stable_61.0.3163.100-1_amd64.deb
#RUN dpkg -i ./google-chrome*.deb
#RUN apt-get install -f
#RUN rm google-chrome*.deb

# create or use the volume depending on how container is run
# ensure that server and client can access the cookie
RUN mkdir -p /Xauthority && chown -R xuser:xusers /Xauthority
VOLUME /Xauthority

# start x11vnc and expose its port
ENV DISPLAY :0.0
EXPOSE 5900
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER xuser

ENTRYPOINT ["/entrypoint.sh"]


#CMD bash
