# cav94mat/docker-maintenance

Schedulable maintenance script for **docker-compose** controlled stacks.

By default, the script performs the follow operations for any stack found in 
the arguments (and optionally subdirectories if `--recurse` or 
`--recurse-one` have been specified):

0. **Run pre-maintenance script(s)**, if specified with `--run-pre`;
1. **Pull images** from the Docker registry;
2. **Side-load images** from a local `docker-sideload.tar` file, if existing;
3. **Build local images**, when source paths are specified in the YAML;
4. **Run maintenance script(s)**, if specified with `--run`;
5. **Re-deploy the stack** restarting or recreating containers whenever required;
6. **Run post-maintenance script(s)**, if specified with `--run-post`;
7. Optionally **perform cleanup operations**, if `--clean` is specified.

You can use `--dry` to simulate the execution and see the logs, without actually doing any operations or running any scripts.

For the entire reference of supported arguments, please run:

```sh
docker run -it --rm cav94mat/docker-maintenance --help
```

## Use with existing stacks
You just need to add a `docker-maintenance` service to your pre-existing _docker-compose.yml_ file:

```yaml
services:
  # [...]
  docker-maintenance:
    command: --clean /srv
    image: cav94mat/docker-maintenance
    environment:
      SCHEDULE: '0 0 * * *' # Replace with the desired cron expression
      TZ: 'Europe/Rome'     # Replace with your timezone
    volumes:
      - './:/srv:z'
      - '/var/run/docker.sock:/var/run/docker.sock:Z'
```
> ⚠ You may want to replace `/srv` both in `command:` and in the first `volumes:` line to
>    reflect the path of the stack in the host system.

### Dedicated stack
This approach is useful if you want to keep the maintenance services in a dedicated stack.

The `--recurse` and `--recurse-one` options may be useful if 

```yaml
version: '3.7'
services:
  docker-maintenance:
    command: --clean --recurse /srv
    image: cav94mat/docker-maintenance
    environment:
      SCHEDULE: '0 0 * * *' # Replace with the desired cron expression
      TZ: 'Europe/Rome'     # Replace with your timezone
    volumes:
      - '/srv:/srv:z'       # Replace `/srv` with the directory of your stack(s)
      - '/var/run/docker.sock:/var/run/docker.sock:Z'
```

### Local installation
You can also install the `docker-maintenance` script locally, in order to launch
the maintenance directly on the host.

Just clone the present repository and run `make install` as root:

```sh
git clone https://github.com/cav94mat/docker-maintenance.git
cd docker-maintenance/
sudo make install
```

The script should be in your PATH, or anyway installed in `/usr/bin/docker-maintenance`.