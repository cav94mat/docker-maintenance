FROM alpine
 ARG BUILD=
 ARG DOCKER_TAG=
 ADD . /src
 RUN apk add --no-cache tini make bash coreutils findutils tzdata docker-cli docker-compose \ 
  && cd /src \
  && OUTPUT_PATH= OUTPUT= INSTALL_DIR= INSTALL_BIN= make install-sys \
  && chmod +x 'docker/entrypoint.sh' \
  && ln -fs /bin/bash /bin/dm-bash \
  && apk del --no-cache -r make
ENTRYPOINT ["/sbin/tini", "/src/docker/entrypoint.sh"]
