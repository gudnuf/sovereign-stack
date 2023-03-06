FROM ubuntu:22.04
RUN apt-get update && apt-get install -y tor
#COPY ./torrc /etc/tor/torrc
#RUN chown root:root /etc/tor/torrc
#RUN chmod 0644 /etc/tor/torrc

#RUN mkdir /data
#VOLUME /data
# RUN chown 1000:1000 -R /data
#USER 1000:1000
CMD tor -f /etc/tor/torrc