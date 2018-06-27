_docker() {
    log --diag "$DOCKER_BIN" "$@"
    [ "$dryrun" ] || "$DOCKER_BIN" "$@"
}
_docker_compose() {
    log --diag "$COMPOSE_BIN" "$@"
    [ "$dryrun" ] || "$COMPOSE_BIN" "$@"
}

[ "$DOCKER_BIN" ] \
    || DOCKER_BIN="docker"
[ "$COMPOSE_BIN" ] \
    || COMPOSE_BIN="docker-compose"
[ "$COMPOSE_FILE" ] \
    || COMPOSE_FILE="docker-compose.yml"