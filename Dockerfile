FROM ubuntu:21.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wait-for-it dnsutils rsync duplicity sshfs snapd lxd-client

RUN mkdir /sovereign-stack
COPY ./ /sovereign-stack
WORKDIR /sovereign-stack

RUN mkdir /site
VOLUME /site
ENV SITE_PATH=/site

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 0744 /entrypoint.sh



CMD /entrypoint.sh