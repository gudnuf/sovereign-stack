FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wait-for-it dnsutils rsync duplicity sshfs snapd lxd-client

RUN mkdir /sovereign-stack
COPY ./deployment /sovereign-stack
WORKDIR /sovereign-stack

RUN mkdir /domain
VOLUME /domain
ENV SITE_PATH=/domain

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 0744 /entrypoint.sh

CMD /entrypoint.sh
