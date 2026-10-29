# gitops-pilot

Bounded pull-delivery pilot (GitOps Phase 2a, workbench task `gitops-p2a-pull-pilot-tuejon`).
[doco-cd](https://github.com/kimdre/doco-cd) on tuejon polls this repository and applies two
internal canary Compose projects. Nothing here is customer-facing: both canaries listen on
loopback only and have no nginx vhost.

| Project | Path | Port (tuejon loopback) | What it tests |
|---|---|---|---|
| `gitops-pilot-whoami` | `whoami/` | `127.0.0.1:8191` | image-digest rollout |
| `gitops-pilot-static` | `static/` | `127.0.0.1:8192` | repo-tracked config rollout, value from a host-only env file |

## How a rollout is approved

- `main` is the desired state. Direct pushes and force pushes to `main` are blocked; a change
  reaches tuejon only when a pull request is merged. The merge is the approval.
- doco-cd polls `main` every 5 minutes. No GitHub runner and no SSH session take part.
- The host decides what doco-cd may manage: `/opt/gitops-pilot/doco-cd/poll.yml` on tuejon
  pins the two project names, their directories and env files (inline deployments override any
  `.doco-cd.yml` in this repo). A PR cannot add a project or take over another Compose project.
- Image pruning and destroy are off. Removing a service from a Compose file removes its
  container (`remove_orphans`) inside that project only.

What a merged PR *can* do: change the Compose content of the two pinned projects, which runs as
root-equivalent Docker on tuejon. Review canary PRs as you would a deploy script: no new host
mounts, no `privileged`, no new public ports.

## Secrets

Values stay on the host in `/opt/gitops-pilot/env/*.env` (root, mode 600). Git holds only the
variable names. `static` requires `PILOT_HOST_SECRET`, a dummy value used to prove the path.

## Host side

`host-reference/` mirrors the live files in `/opt/gitops-pilot/doco-cd/` on tuejon. They are
documentation: changing them here deploys nothing. doco-cd reaches Docker only through a socket
proxy that denies exec, build, plugins, swarm, secrets and system endpoints.

Pause all rollouts without stopping the canaries: set `pause: true` on the deployments in the
host `poll.yml` and restart doco-cd. Tear the pilot down:

```sh
cd /opt/gitops-pilot/doco-cd && sudo docker compose down          # stops doco-cd and the proxy
sudo docker compose -p gitops-pilot-whoami down
sudo docker compose -p gitops-pilot-static down
```

Runtime state, measurements and the go/no-go record live in the workbench under
`evidence/2026-10-29-gitops-p2a-pull-pilot/`.
