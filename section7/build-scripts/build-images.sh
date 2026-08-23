#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/.build-logs"
DEFAULT_SERVICES=(configserver accounts loans cards)

PARALLEL=false
PUSH=false
SERVICES=()

# Usage (run from the repo root):
#   ./build-scripts/build-images.sh                    build all services sequentially into the local Docker daemon
#   ./build-scripts/build-images.sh accounts cards     build only the named services
#   ./build-scripts/build-images.sh --parallel         build all services concurrently
#   ./build-scripts/build-images.sh -p accounts cards  build named services concurrently
#   ./build-scripts/build-images.sh --push             build locally, then `docker push` each image (needs `docker login`)
#   ./build-scripts/build-images.sh -p --push cards    combine flags and service names freely
for arg in "$@"; do
  case "$arg" in
    --parallel|-p)
      PARALLEL=true
      ;;
    --push)
      PUSH=true
      ;;
    *)
      SERVICES+=("$arg")
      ;;
  esac
done

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=("${DEFAULT_SERVICES[@]}")
fi

# Reads the Jib `<to><image>` value straight out of the service's pom.xml so the image
# ref used for `docker push` can never drift out of sync with what was just built.
image_ref() {
  local service="$1" raw
  raw="$(grep -m1 -oE '<image>[^<]*</image>' "${PROJECT_ROOT}/${service}/pom.xml" | sed -E 's#</?image>##g')"
  echo "${raw//\$\{project.artifactId\}/${service}}"
}

build_service() {
  local service="$1"
  (
    cd "${PROJECT_ROOT}/${service}" &&
    mvn compile jib:dockerBuild &&
    if [[ "$PUSH" == true ]]; then
      docker push "$(image_ref "$service")"
    fi
  )
}

ACTION="built"
if [[ "$PUSH" == true ]]; then
  ACTION="built and pushed"
fi

if [[ "$PARALLEL" == true ]]; then
  mkdir -p "$LOG_DIR"
  pids=()
  names=()
  for service in "${SERVICES[@]}"; do
    echo "==> Starting build for ${service} (log: .build-logs/${service}.log)"
    build_service "$service" > "${LOG_DIR}/${service}.log" 2>&1 &
    pids+=("$!")
    names+=("$service")
  done

  failed=()
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      failed+=("${names[$i]}")
    fi
  done

  echo
  if [[ ${#failed[@]} -eq 0 ]]; then
    echo "==> All images ${ACTION} successfully: ${SERVICES[*]}"
  else
    echo "==> Build FAILED for: ${failed[*]}"
    echo "    See logs in ${LOG_DIR} for details"
    exit 1
  fi
else
  set -e
  for service in "${SERVICES[@]}"; do
    echo "==> Building image for ${service}"
    build_service "$service"
  done
  echo "==> All images ${ACTION}: ${SERVICES[*]}"
fi
