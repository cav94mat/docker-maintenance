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