#!/usr/bin/env bash
# Live copy: tuejon /opt/gitops-pilot/teardown.sh (run with sudo).
#   teardown.sh stop    kill switch: revoke Docker API access first, then stop doco-cd.
#                       The canaries keep running; nothing is removed.
#   teardown.sh remove  stop, then remove both canary projects and the controller project
#                       (containers and networks selected by Compose project label only).
#                       Images, the doco-cd data volume and /opt/gitops-pilot stay until
#                       removed by hand; this script never prunes anything host-wide.
set -euo pipefail
mode="${1:-}"
cd /

stop_controller() {
  # Stopping the proxy first means an in-flight doco-cd operation cannot issue further calls.
  docker ps -q --filter label=com.docker.compose.project=gitops-pilot-cd \
    --filter label=com.docker.compose.service=socket-proxy | xargs -r docker stop
  docker ps -q --filter label=com.docker.compose.project=gitops-pilot-cd \
    --filter label=com.docker.compose.service=doco-cd | xargs -r docker stop
}

remove_project() {
  local project="$1"
  docker ps -aq --filter "label=com.docker.compose.project=${project}" | xargs -r docker rm -f
  docker network ls -q --filter "label=com.docker.compose.project=${project}" | xargs -r docker network rm
}

case "$mode" in
  stop)
    stop_controller ;;
  remove)
    stop_controller
    remove_project gitops-pilot-whoami
    remove_project gitops-pilot-static
    remove_project gitops-pilot-cd
    echo "left in place: volume gitops-pilot-cd_data, images, /opt/gitops-pilot" ;;
  *)
    echo "usage: $0 stop|remove" >&2; exit 2 ;;
esac
docker ps -a --filter label=twb.owner=gitops-p2a-pull-pilot-tuejon --format '{{.Names}}\t{{.Status}}'
