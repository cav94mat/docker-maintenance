FROM alpine
LABEL com.cav94mat.maintenance.keepalive=1
 RUN apk add --no-cache make bash findutils tzdata docker-cli docker-compose 
 ADD . /src
 RUN cd /src \
  && OUTPUT_PATH= OUTPUT= INSTALL_DIR= INSTALL_BIN= make install-sys \
  && chmod +x 'docker/entrypoint.sh' \
  && apk del --no-cache -r make
ENTRYPOINT ["/src/docker/entrypoint.sh"]