FROM alpine
LABEL com.cav94mat.maintenance.keepalive=1
 RUN apk add --no-cache make bash findutils tzdata docker-cli docker-compose 
 ADD . /src
 RUN cd /src \
  && make install \
  && chmod +x 'src-docker/docker.sh' \
  && apk del --no-cache -r make
ENTRYPOINT ["/src/src-docker/docker.sh"]