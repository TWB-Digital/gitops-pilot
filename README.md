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
- The host decides which projects doco-cd deploys: `/opt/gitops-pilot/doco-cd/poll.yml` on
  tuejon pins the two project names, their directories and env files (inline deployments
  override any `.doco-cd.yml` in this repo). A PR cannot add a project or redeploy another
  Compose project by name.
- Image pruning and destroy are off. Removing a service from a Compose file removes its
  container (`remove_orphans`) inside that project only.

### What still has to be trusted

The project pin limits what doco-cd *selects*; it is not a sandbox. A merged Compose change
runs with Docker's authority on tuejon, the same trust as today's push deploys where a merge to
`main` runs a deploy script on the host. A socket proxy narrows that authority:

- allowed: read calls, image pull, container create/start/stop/restart/kill/rename/remove,
  network and volume create, network connect/disconnect;
- denied: exec, build, image/volume/network deletion, every prune endpoint, plugins, swarm,
  secrets, configs, system;
- bind mounts only from doco-cd's own data volume, so no `/`, no `/var/run/docker.sock`,
  no host paths.

Not prevented: `privileged`, `cap_add`, host network/PID namespaces, attaching to another
project's network or named volume. Review canary PRs for exactly these; the daily pilot check
inspects the running canaries for them.

## Secrets

Values stay on the host in `/opt/gitops-pilot/env/*.env` (root, mode 600). Git holds only the
variable names. `static` requires `PILOT_HOST_SECRET`, a dummy value used to prove the path.

## Host side

`host-reference/` mirrors the live files on tuejon (`/opt/gitops-pilot/doco-cd/compose.yml`,
`poll.yml`, `/opt/gitops-pilot/teardown.sh`). They are documentation: changing them here
deploys nothing. They and `/opt/gitops-pilot/env/` are frozen for the pilot week: an edit there
can redeploy at an unchanged commit, so every edit is logged in the workbench evidence.

- **Kill switch:** `sudo /opt/gitops-pilot/teardown.sh stop` stops the socket proxy first (no
  further Docker API calls), then doco-cd. The canaries keep running.
- **Freeze rollouts but keep recovery off too:** set `pause: true` and `reconciliation: false`
  on the deployments in the host `poll.yml`, then restart doco-cd.
- **Tear down:** `sudo /opt/gitops-pilot/teardown.sh remove` removes the canary and controller
  containers and networks by Compose project label. It leaves images, the
  `gitops-pilot-cd_data` volume and `/opt/gitops-pilot` for manual removal and never prunes
  host-wide.

Runtime state, measurements and the go/no-go record live in the workbench under
`evidence/2026-10-29-gitops-p2a-pull-pilot/`.
