FROM ruby:3
COPY ./ /src/
RUN cd /src ; gem build balboa_worldwide_app.gemspec
RUN cd /src ; gem install ./*.gem
RUN find / -name bwa_mqtt_bridge
ARG MQTT_HOST
ENV LOG_LEVEL INFO
ENV LOG_VERBOSITY 0
CMD /usr/local/bundle/bin/bwa_mqtt_bridge mqtt://$MQTT_HOST/ /dev/ttyHotTub
