_docker() {
    log --diag "$DOCKER_BIN" "$@"
    [ "$dryrun" ] || "$DOCKER_BIN" "$@"
}
_docker_compose() {
    log --diag "$COMPOSE_BIN" "$@"
    if [ "$DEBUG"]; then
        [ "$dryrun" ] || "$COMPOSE_BIN" "$@"
    else
        [ "$dryrun" ] || "$COMPOSE_BIN" --verbose "$@"
    fi
}

[ "$DOCKER_BIN" ] \
    || DOCKER_BIN="docker"
[ "$COMPOSE_BIN" ] \
    || COMPOSE_BIN="docker-compose"
[ "$COMPOSE_FILE" ] \
    || COMPOSE_FILE="docker-compose.yml"