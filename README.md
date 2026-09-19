# OCI Skeleton

This repository serves as a skeleton and template for taking prebuilt, open-source container images and making them compliant with **OpenShift** and **Talos Linux** security and deployment requirements. It also includes an accompanying **Helm chart** to simplify deployment.

## Purpose

Often, standard open-source container images run as the `root` user or require specific privileges that are not allowed by default in highly secure, restricted environments like OpenShift (which enforces strict SCCs) and Talos Linux.

This skeleton provides a standardized approach to:
- Modify existing open-source Dockerfiles to run as non-root users.
- Adjust permissions and file ownership to comply with OpenShift's arbitrary UID requirements.
- Package the deployment configurations into a flexible, easily deployable Helm chart.

## Features

- **OpenShift Compliance**: Configured to run without root privileges and handle arbitrary user IDs.
- **Talos Linux Compatibility**: Follows security best practices suitable for immutable, secure-by-default Kubernetes operating systems.
- **Helm Chart Included**: Comes with a ready-to-use Helm chart (`chart/`) for templated, reproducible deployments.
- **GitHub Actions CI**: Automated workflows to build and push images based on versions defined in `versions.json`.
- **Example Implementation**: Includes an NGINX implementation out-of-the-box to demonstrate the necessary modifications.

## Repository Structure

- `Dockerfile`: The template Dockerfile demonstrating how to adapt an image (NGINX by default) for compliance.
- `chart/`: The accompanying Helm chart for deploying the application.
- `compose.yml`: For local testing and development of the modified image.
- `compose.upstream.yml`: For local testing and benchmarking against the unmodified upstream image.
- `versions.json`: Used by CI workflows to determine which versions of the image to build.
- `.github/workflows/`: CI/CD pipelines for building and pushing the images.

## Local Environment & Podman Setup

To ensure containerized applications and Helm charts tested locally run cleanly when deployed to OpenShift or Talos Linux, this repository is designed to be used alongside the Podman configuration in [joeckr/dotfiles](https://github.com/joeckr/dotfiles).

The dotfiles repository provides a centralized [`containers.conf`](https://github.com/joeckr/dotfiles/blob/main/containers/containers.conf) (deployed to `~/.config/containers/containers.conf`) that configures Podman to simulate OpenShift's default **`restricted-v2` Security Context Constraints (SCC)**:

| OpenShift SCC Rule | Podman Configuration | Description |
|---|---|---|
| **Random UID (`MustRunAsRange`)** | `userns = "auto"` | Allocates dynamic subordinate UID/GID ranges from `/etc/subuid` and `/etc/subgid`. Containers run unprivileged without mapping host root. |
| **Drop Capabilities** | `default_capabilities = ["NET_BIND_SERVICE"]` | Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only `NET_BIND_SERVICE`. |
| **Disallow Privileged** | `privileged = false` | Disallows privileged container execution by default. |
| **Seccomp Profile** | `seccomp_profile = "/usr/share/containers/seccomp.json"` | Enforces the runtime default seccomp profile (`RuntimeDefault`). |
| **Namespace Isolation** | `cgroupns`, `ipcns`, `pidns`, `utsns = "private"` | Enforces private container namespaces (host namespaces are forbidden in restricted SCC). |

### macOS Podman Machine Integration

On macOS, the dotfiles installer script (`brew/podman.sh`) automates the machine lifecycle:

1. Deploys `containers/containers.conf` to `~/.config/containers/containers.conf` on the host.
2. Initializing `podman machine init` automatically mounts `~/.config/containers` into `/etc/containers` inside the Fedora CoreOS VM.
3. Automatically symlinks `/etc/containers/containers.conf` to the VM user's config (`~core/.config/containers/containers.conf`) and restarts the Podman API service so all container executions immediately enforce these constraints.

## Testing with Podman Compose

Two Compose configurations are provided to facilitate testing, benchmarking, and debugging:

### 1. Upstream Baseline (`compose.upstream.yml`)

The `compose.upstream.yml` file runs the original, unmodified upstream container image (e.g., `nginx:1.31.5-alpine`):

```sh
# Start upstream container
podman compose -f compose.upstream.yml up -d

# Or via mise
mise run compose-up
```

**Why test upstream?**
Running the unmodified image against your SCC-compliant Podman setup simulates deploying standard public images directly into OpenShift. This will typically surface common failures:
- Processes attempting to run as `root` (UID 0) or create/access files without appropriate group permissions.
- Inability to write to system or cache directories (such as `/var/cache/nginx`).
- Failure to bind privileged ports (< 1024) due to dropped capabilities.

### 2. Modified Image (`compose.yml`)

The `compose.yml` file builds and runs the customized `Dockerfile` containing the adaptations required for OpenShift and Talos Linux:

```sh
# Build and start the modified compliant container
podman compose up -d --build

# Or via mise
mise run compose
```

This verified configuration applies:
- Non-root user execution (`USER 1031`).
- Root group ownership (`chgrp -R 0`) and group read/write permissions (`chmod -R g+rwX`) on runtime paths (`/tmp/nginx`, `/var/cache/nginx`, `/app`), allowing OpenShift's arbitrary assigned UIDs to execute and write properly.
- Unprivileged port bindings (`8080`).
- An `entrypoint.sh` script to dynamically handle runtime configuration and templating under arbitrary UIDs.

### Stopping Containers

```sh
# Stop modified compose stack
podman compose down
# or: mise run down

# Stop upstream compose stack
podman compose -f compose.upstream.yml down
# or: mise run down-up
```

## Getting Started

1. **Use as a Template**
   Clone or use this repository as a template for your own project.

2. **Modify the Dockerfile**
   Update the `Dockerfile` to base it on your desired open-source image. Ensure that you maintain the non-root user configurations and adjust permissions for any directories your application needs to write to (e.g., using `chgrp -R 0` and `chmod -R g+rwX`).

3. **Update the Helm Chart**
   Navigate to the `chart/` directory and update `Chart.yaml`, `values.yaml`, and the templates to reflect your application's specifics.

4. **Configure Build Versions**
   Update `versions.json` with the upstream image versions you wish to build.

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
