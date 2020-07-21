docker() {
    log --diag $DOCKER_BIN "$@"
    [ "$dryrun" ] || command $DOCKER_BIN "$@"
}
docker-compose() {
    log --diag $COMPOSE_BIN "$@"
    [ "$dryrun" ] || command $COMPOSE_BIN -f "$COMPOSE_FILE" "$@"
}

[ "$DOCKER_BIN" ] \
    || DOCKER_BIN="docker"
[ "$COMPOSE_BIN" ] \
    || COMPOSE_BIN="docker-compose"
[ "$COMPOSE_FILE" ] \
    || COMPOSE_FILE="docker-compose.yml"  

if [ -z "$DOCKER_SOCK" ]; then
    DOCKER_SOCK='/var/run/docker.sock'
    [[ "$DOCKER_HOST" == "unix://"* ]] \
        && DOCKER_SOCK="${DOCKER_HOST:7}"
fi