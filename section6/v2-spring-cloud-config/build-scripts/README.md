# build-scripts

Build (and optionally push) the Docker images for all microservices (`configserver`,
`accounts`, `loans`, `cards`) with one command, instead of running
`mvn compile jib:dockerBuild` and `docker image push ...` by hand in each module directory.

## Contents

| File               | Platform      | Purpose                                   |
|--------------------|---------------|--------------------------------------------|
| `build-images.sh`  | macOS / Linux | Bash script, same behavior as the `.cmd`  |
| `build-images.cmd` | Windows       | Batch script, same behavior as the `.sh`  |

Both scripts resolve paths relative to their own location, so the service folders
(`configserver/`, `accounts/`, `loans/`, `cards/`) must stay one level above `build-scripts/`
at the repo root — you don't need to run the scripts from any particular working directory.

When run with `--parallel`/`-p`, each service's Maven output is written to
`build-scripts/.build-logs/<service>.log` (created automatically, safe to delete between runs).

## Prerequisites

- Maven (`mvn`) on your `PATH`
- Docker daemon running locally (Jib's `dockerBuild` goal loads the image straight into it, and `--push` reuses that same local image for `docker push`)
- For `--push`: run `docker login` once beforehand, same as you would before `docker image push`

## Usage

Run from the repository root.

### macOS / Linux

```bash
./build-scripts/build-images.sh                    # build all 4 services, one at a time
./build-scripts/build-images.sh accounts cards      # build only the named services
./build-scripts/build-images.sh --parallel          # build all 4 services concurrently
./build-scripts/build-images.sh -p accounts cards   # build named services concurrently
./build-scripts/build-images.sh --push              # build all 4 locally, then push each to Docker Hub
./build-scripts/build-images.sh -p --push cards     # push just cards, and combine with -p
```

If the script ever loses its executable bit (e.g. after a fresh clone on some setups), restore it with:

```bash
chmod +x build-scripts/build-images.sh
```

### Windows

From Command Prompt or PowerShell:

```bat
build-scripts\build-images.cmd
build-scripts\build-images.cmd accounts cards
build-scripts\build-images.cmd --parallel
build-scripts\build-images.cmd -p accounts cards
build-scripts\build-images.cmd --push
build-scripts\build-images.cmd -p --push cards
```

## Behavior

- **No arguments**: builds all four services, `configserver accounts loans cards`.
- **Service names as arguments**: builds only the services listed, in the order given.
- **`--parallel` / `-p`**: builds the selected services concurrently instead of one at a time.
  Progress and errors for each service go to its own log file under `.build-logs/`; a summary
  is printed once every build finishes.
- **`--push`**: after each service builds successfully into the local Docker daemon (same
  `jib:dockerBuild` step as always), runs `docker push` for that image before moving on —
  the same two steps you'd run by hand, just chained together and never pushing a build that
  failed. The image ref is read straight out of each service's `pom.xml` (`<to><image>`,
  currently `eazybytes/<service>:s6` on Docker Hub) rather than hardcoded here, so it can't
  drift out of sync if the tag changes later. Combine freely with `--parallel`/`-p` and
  specific service names.
- **Exit code**: non-zero if any service fails to build (or push). In sequential mode the script
  stops at the first failure; in parallel mode all builds run to completion and the failing
  service(s) are listed at the end.
