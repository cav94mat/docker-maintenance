FROM alpine
 RUN apk add --no-cache tini make bash findutils tzdata docker-cli docker-compose 
 ADD . /src
 RUN cd /src \
  && OUTPUT_PATH= OUTPUT= INSTALL_DIR= INSTALL_BIN= make install-sys \
  && chmod +x 'docker/entrypoint.sh' \
  && apk del --no-cache -r make
ENTRYPOINT ["/sbin/tini", "/src/docker/entrypoint.sh"]
