# docker-maintenance

Schedulable maintenance script for **docker-compose** controlled stacks.

## 1. Installing
Clone this repository, then run `sudo make install` to assemble and install 
the main script.

## 2. Usage
You can invoke `docker-maintenance --help` for the complete instructions.

By default, the script performs the follow operations for any stack found in 
the arguments (and optionally subdirectories if `--recurse` or 
`--recurse-one` have been specified):

1. (If supplied with `--run-pre`): Execute pre-maintenance scripts;
2. Pull image updates (skipped if `--no-pull` was specified);
3. Load images from a local `docker-sideload.tar` source (skipped if the archive doesn't exist, or if `--no-sideload` was specified)
4. Build local images (skipped if `--no-build` was specified);
5. Stops all the containers in the stack
6. (If supplied with `--run`): Execute maintenance scripts;
7. Re-deploys the stack (skipped if `--no-up` was specified)
8. (If supplied with `--run-pre`): Execute post-maintenance scripts;
9. (If `--clean` or `--clean-dangling` are specified) performs docker cleanup operations (will remove unused images and stopped containers!)

You can use `--dry` to simulate the execution and see the logs, without actually doing any operations or running any scripts.
