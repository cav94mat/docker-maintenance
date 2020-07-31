docker() {
    #log --diag $DOCKER_BIN "$@"
    command $DOCKER_BIN "$@"
}
export -f docker

docker-compose() {
    #log --diag $COMPOSE_BIN "$@"
    command $COMPOSE_BIN --no-ansi -f "$COMPOSE_FILE" "$@"
}
export -f docker-compose

[ "$DOCKER_BIN" ] \
    || DOCKER_BIN="docker"
[ "$COMPOSE_BIN" ] \
    || COMPOSE_BIN="docker-compose"
[ "$COMPOSE_FILE" ] \
    || COMPOSE_FILE="docker-compose.yml"  
[ "$DOCKER_SIDELOAD" ] \
    || DOCKER_SIDELOAD="docker-sideload.tar"

if [ -z "$DOCKER_SOCK" ]; then
    DOCKER_SOCK='/var/run/docker.sock'
    [[ "$DOCKER_HOST" == "unix://"* ]] \
        && DOCKER_SOCK="${DOCKER_HOST:7}"
fi