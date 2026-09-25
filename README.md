# OCI Skeleton

This repository serves as a skeleton and template for taking prebuilt, open-source container images and making them compliant with **OpenShift** and **Talos Linux** security and deployment requirements. It also includes an accompanying **Helm chart** to simplify deployment.

## Purpose

Often, standard open-source container images run as the `root` user or require specific privileges that are not allowed by default in highly secure, restricted environments like OpenShift (which enforces strict SCCs) and Talos Linux (which enforces strict Kubernetes Pod Security Standards).

This skeleton provides a standardized approach to:
- Modify existing open-source Dockerfiles to run as non-root users and **build cleanly in rootless environments**.
- Adjust permissions and file ownership to comply with OpenShift's arbitrary UID requirements and Talos Linux's immutable, restricted pod standards.
- Package the deployment configurations into a flexible, easily deployable Helm chart that supports both Kubernetes Ingress and OpenShift Routes.
- Provide a multi-tiered testing pipeline spanning local Podman Compose, local Kubernetes manifest execution via `podman play kube`, and end-to-end deployment on a live Talos Linux cluster.

## Features

- **Rootless Image Builds**: Engineered to build cleanly in unprivileged, rootless container builders (such as rootless Podman, Buildah, or unprivileged CI runners) without requiring host root or privileged daemon sockets.
- **OpenShift Compliance**: Configured to run without root privileges and handle arbitrary runtime user IDs under the `restricted-v2` Security Context Constraint (SCC).
- **Talos Linux Compatibility**: Fully compliant with upstream Kubernetes Pod Security Standards (`restricted` PSS/PSA level) suited for Talos Linux's immutable, hardened architecture.
- **Dual Ingress & Route Support**: Helm chart cleanly toggles between standard Kubernetes `Ingress` (`networking.k8s.io/v1`) for Talos and OpenShift `Route` (`route.openshift.io/v1`).
- **Helm Chart Included**: Comes with a ready-to-use Helm chart (`chart/`) for templated, reproducible deployments with hardened pod security contexts.
- **Mise Task Automation**: Built-in `mise` tasks for local compose testing, `podman play kube` simulation, linting, rendering, and cluster deployment.
- **GitHub Actions CI**: Automated workflows to build and push images based on versions defined in `versions.json`.
- **Example Implementation**: Includes an NGINX implementation out-of-the-box to demonstrate the necessary modifications.

## Repository Structure

- `Dockerfile`: The template Dockerfile demonstrating how to adapt an image (NGINX by default) for compliance.
- `chart/`: The accompanying Helm chart for deploying the application to OpenShift or Talos Linux.
- `compose.yml`: For local testing and development of the modified image.
- `compose.upstream.yml`: For local testing and benchmarking against the unmodified upstream image.
- `mise.toml`: Task runner configuration automating build, compose, play, lint, and cluster deployment workflows.
- `versions.json`: Used by CI workflows to determine which versions of the image to build.
- `.github/workflows/`: CI/CD pipelines for building and pushing the images.

## Security & Compliance Architecture

Both OpenShift and Talos Linux prioritize workload security and least privilege, but they enforce and evaluate constraints through different mechanisms. This repository is architected to satisfy both environments without code changes.

### OpenShift Compliance (`restricted-v2` SCC)

OpenShift uses **Security Context Constraints (SCC)** to control pod permissions. Under the default `restricted-v2` SCC:
- **Arbitrary Dynamic UIDs**: OpenShift assigns a random UID from a dedicated per-namespace range (e.g., `1000670000`). Containers cannot assume a fixed UID like `1000`.
- **Root Group (GID 0)**: Files and directories required at runtime must be owned by group 0 (`chgrp -R 0`) with group read/write permissions (`chmod -R g+rwX`) so the dynamically assigned UID can access them.
- **Dropped Capabilities**: Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only unprivileged operations (and `NET_BIND_SERVICE` when needed).
- **Unprivileged Ports**: Containers must listen on non-privileged ports (> 1024), such as port `8080`.
- **Routing**: OpenShift natively supports `route.openshift.io/v1` Routes for external ingress traffic.

### Talos Linux Compliance (Kubernetes PSS `restricted`)

Talos Linux is an immutable, minimal, secure-by-default Kubernetes operating system with no SSH, no interactive shell, and an immutable root filesystem. In Talos clusters:
- **Pod Security Standards (PSS)**: Workload namespaces enforce the Kubernetes **Pod Security Admission (PSA)** `restricted` profile.
- **Must Run As Non-Root**: The pod specification must set `securityContext.runAsNonRoot: true`. Containers cannot execute as UID 0.
- **Drop All Capabilities**: The container specification must explicitly drop all Linux capabilities (`capabilities: drop: ["ALL"]`).
- **Disallow Privilege Escalation**: Must set `securityContext.allowPrivilegeEscalation: false` to prevent child processes from acquiring more privileges than the parent.
- **Seccomp Profile**: Pods must enforce `seccompProfile: { type: RuntimeDefault }`.
- **Credential Protection**: Best practice sets `automountServiceAccountToken: false` to avoid leaking Kubernetes API tokens to application containers unless explicitly needed.
- **Standard Ingress & Storage**: Talos relies on standard Kubernetes `networking.k8s.io/v1` `Ingress` (e.g., via Cilium, Traefik, or Ingress-NGINX) and CSI storage providers (e.g., Local Path Provisioner, OpenEBS Mayastor, Rook-Ceph).

### Rootless Build Environment Compliance

Building container images inside secure or unprivileged environments (such as rootless Podman/Buildah on developer workstations, or unprivileged Kubernetes CI runners like Tekton or Kaniko) requires that the build process itself does not rely on host `root` privileges or the legacy root-owned Docker daemon socket (`/var/run/docker.sock`).

This repository's `Dockerfile` is engineered for complete rootless build support:
- **No Host Root Required**: Builds execute and succeed cleanly under unprivileged user namespaces without needing `sudo` or privileged container builders.
- **User Namespace Friendly Permissions**: Layer modifications rely on `chgrp -R 0` and group-based permissions (`g+rwX`), which map cleanly into subordinate UID/GID allocations (`/etc/subuid` and `/etc/subgid`) without failing on host-restricted `chown` operations.
- **Atomic Copy Permissions**: Uses `COPY --chmod=755` directly rather than invoking privileged `chmod` steps in subsequent `RUN` layers.
- **Unprivileged Local Build**: Run `mise run build` (`podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/oci-modified:test . --load`) or `mise run compose` to build locally without root escalation.

### Compliance Matrix

| Security Dimension | OpenShift (`restricted-v2` SCC) | Talos Linux (Kubernetes PSS `restricted`) | Implementation in This Repo |
|---|---|---|---|
| **Build Execution** | Rootless builder compatible | Rootless builder compatible | Builds unprivileged via rootless Podman/Buildah (`mise run build`) |
| **User ID** | Dynamic arbitrary UID (`MustRunAsRange`) | Non-root UID (`runAsNonRoot: true`) | `USER 1031` in Dockerfile + `runAsNonRoot: true` in Helm |
| **Group Permissions** | Requires GID 0 (`root`) with `g+rwX` | Compatible with GID 0 / unprivileged groups | `chgrp -R 0` & `chmod -R g+rwX` on runtime paths |
| **Capabilities** | Drops root caps; allows `NET_BIND_SERVICE` | Must drop `ALL` capabilities | `capabilities.drop: ["ALL"]` in Helm chart |
| **Privilege Escalation** | Prohibited | `allowPrivilegeEscalation: false` | Configured in Helm `securityContext` |
| **Seccomp Profile** | `RuntimeDefault` | `RuntimeDefault` or `Localhost` | `seccompProfile: { type: RuntimeDefault }` |
| **Service Account Token** | Optional | Recommended disabled | `automountServiceAccountToken: false` |
| **Port Binding** | Unprivileged (> 1024) | Unprivileged (> 1024) | Listens on port `8080` |
| **Ingress Layer** | OpenShift Route (`route.openshift.io/v1`) | Kubernetes Ingress (`networking.k8s.io/v1`) | Configurable via `ingress.route: "true"` or `"false"` |
| **Storage Layer** | OpenShift StorageClass | Talos CSI StorageClass | Standard PVC template with configurable `storageClass` |

---

## Local Environment & Podman Setup

To ensure containerized applications and Helm charts tested locally run cleanly when deployed to OpenShift or Talos Linux, this repository is designed to be used alongside the Podman configuration in [joeckr/dotfiles](https://github.com/joeckr/dotfiles).

The dotfiles repository provides a centralized [`containers.conf`](https://github.com/joeckr/dotfiles/blob/main/containers/containers.conf) (deployed to `~/.config/containers/containers.conf`) that configures Podman to simulate OpenShift and Talos Linux runtime restrictions:

| Security Rule | Podman Configuration | Description |
|---|---|---|
| **Random UID (`MustRunAsRange`)** | `userns = "auto"` | Allocates dynamic subordinate UID/GID ranges from `/etc/subuid` and `/etc/subgid`. Containers run unprivileged without mapping host root. |
| **Drop Capabilities** | `default_capabilities = ["NET_BIND_SERVICE"]` | Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only `NET_BIND_SERVICE`. |
| **Disallow Privileged** | `privileged = false` | Disallows privileged container execution by default. |
| **Seccomp Profile** | `seccomp_profile = "/usr/share/containers/seccomp.json"` | Enforces the runtime default seccomp profile (`RuntimeDefault`). |
| **Namespace Isolation** | `cgroupns`, `ipcns`, `pidns`, `utsns = "private"` | Enforces private container namespaces (host namespaces are forbidden in restricted profiles). |

### macOS Podman Machine Integration

On macOS, the dotfiles installer script (`brew/podman.sh`) automates the machine lifecycle:

1. Deploys `containers/containers.conf` to `~/.config/containers/containers.conf` on the host.
2. Initializing `podman machine init` automatically mounts `~/.config/containers` into `/etc/containers` inside the Fedora CoreOS VM.
3. Automatically symlinks `/etc/containers/containers.conf` to the VM user's config (`~core/.config/containers/containers.conf`) and restarts the Podman API service so all container executions immediately enforce these constraints.

---

## Testing & Validation Process

This repository defines a 4-tier testing process to validate container security, manifest generation, and runtime compatibility from local development through to production cluster deployment.

```
┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐
│ Tier 1: Upstream Test   │ ──> │ Tier 2: Modified Test   │ ──> │ Tier 3: Podman Play     │ ──> │ Tier 4: Talos Cluster   │
│ Surface root & cap gaps │     │ Verify non-root & fixes │     │ Validate K8s manifests  │     │ Live Helm verification  │
│ (compose.upstream.yml)  │     │ (compose.yml)           │     │ (podman play kube)      │     │ (helm install)          │
└─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘
```

### Tier 1: Upstream Baseline Comparison (`compose.upstream.yml`)

The `compose.upstream.yml` configuration runs the original, unmodified upstream container image (e.g., `nginx:1.31.5-alpine`):

```sh
# Start upstream container
podman compose -f compose.upstream.yml up -d

# Stop upstream container
podman compose -f compose.upstream.yml down
```

**Why test upstream?**
Running the unmodified image against your restricted Podman environment simulates deploying standard public images directly into OpenShift or Talos Linux. This will typically surface common failures:
- Processes attempting to run as `root` (UID 0) or create/access files without appropriate group permissions.
- Inability to write to system or cache directories (such as `/var/cache/nginx`).
- Failure to bind privileged ports (< 1024) due to dropped capabilities.

---

### Tier 2: Modified Image Local Validation (`compose.yml`)

The `compose.yml` configuration builds and runs the customized `Dockerfile` containing the adaptations required for OpenShift and Talos Linux:

```sh
# Build and start the modified compliant container
mise run compose
# or: podman compose up -d --build

# View container logs
mise run logs
# or: podman compose logs -f

# Verify connectivity
curl http://localhost:8080

# Stop modified stack
mise run down
# or: podman compose down
```

**What this verifies:**
- Rootless image build and layer assembly without host root privileges.
- Non-root user execution (`USER 1031`).
- Root group ownership (`chgrp -R 0`) and group read/write permissions (`chmod -R g+rwX`) on runtime paths (`/tmp/nginx`, `/var/cache/nginx`, `/app`).
- Unprivileged port binding (`8080`).
- The `entrypoint.sh` script dynamically handling runtime configuration and templating under non-root UIDs.

---

### Tier 3: Local Kubernetes Manifest Testing (`mise run play`)

Before deploying to an actual Kubernetes cluster, you can test the rendered Kubernetes manifests locally using Podman's built-in `play kube` feature.

```sh
# Render templates and play Kubernetes manifests locally
mise run play

# Teardown the played pod and resources
mise run play-d
```

**How `mise run play` works:**
1. Triggers the dependent task `mise run helm-t`, which executes:
   ```sh
   helm dependency build chart/
   helm template test chart/ > rendered.yaml
   ```
2. Executes `podman play kube rendered.yaml`, which:
   - Reads the multi-document Kubernetes YAML (`ConfigMap`, `PersistentVolumeClaim`, `Service`, `Deployment`, `Ingress`).
   - Creates a local Podman pod matching the Kubernetes `Deployment` specification.
   - Applies the pod's `securityContext` (`runAsNonRoot: true`, capabilities drop, seccomp profile).
   - Mounts the `ConfigMap` (`template.txt`) and volume into the container at the specified paths.
   - Exposes container port `8080`.

**Inspecting the local play deployment:**
```sh
# View running pods created by play kube
podman pod ps

# View container status within the pod
podman ps --filter "pod=oci-modified"

# Verify the service responds
curl http://localhost:8080

# Check container logs within the pod
podman logs -f oci-modified-pod-oci-modified
```

**Teardown:**
```sh
mise run play-d
# or: podman play kube rendered.yaml --down
```

---

### Tier 4: Cluster Deployment & Testing on Talos Linux (`mise run helm-i`)

The final phase validates the workload on a live **Talos Linux** Kubernetes cluster. This tests real-world Pod Security Admission (PSA) enforcement, CSI storage provisioning, network policies, and Ingress routing.

#### 1. Cluster Prerequisites & Configuration

Ensure your `kubectl` context points to your Talos cluster:
```sh
kubectl config current-context
# Example: admin@my-talos-cluster
```

Ensure the container image is accessible to your Talos nodes (e.g., built and pushed to GitHub Container Registry `ghcr.io` or your local registry):
```sh
# Build image locally with target tag
mise run build
```

Configure `chart/values.yaml` for Talos Linux:
- **Ingress vs. Route**: Ensure `ingress.route` is set to `"false"` (default) so Helm generates standard Kubernetes `networking.k8s.io/v1` `Ingress` rather than an OpenShift Route:
  ```yaml
  ingress:
    name: template-ingress
    host: "test.yourdomain.com"
    route: "false"                 # "false" for Talos / vanilla Kubernetes; "true" for OpenShift
    className: "nginx"             # e.g., "nginx", "traefik", or "cilium"
    path: /
    pathType: "Prefix"
  ```
- **StorageClass**: If your Talos cluster uses a specific CSI storage provisioner (e.g., `local-path`, `mayastor`, `ceph-block`), configure `pvc.storageClass` in `values.yaml` or leave it empty `""` to use the cluster's default StorageClass.
- **Security Context & fsGroup**: Under `template.podSecurityContext`, `fsGroup: 1031` ensures mounted volumes are writable by the container user in vanilla Kubernetes / Talos Linux. If deploying to OpenShift, remove or comment out `fsGroup` as OpenShift's SCC dynamically allocates fsGroups.

#### 2. Linting & Template Validation

```sh
# Lint the chart for syntax and formatting errors
mise run helm-l

# Inspect the rendered manifests before installation
mise run helm-t
cat rendered.yaml
```

#### 3. Deploying to the Talos Cluster

Install the Helm chart release:
```sh
mise run helm-i
# or: helm install test chart/
```

#### 4. Verifying Talos PSS Compliance & Health

Check the pod status and verify that Talos Linux Pod Security Admission (PSA) allowed the pod to run:

```sh
# Check pod deployment status
kubectl get pods -l app=oci-modified

# Inspect pod details and events for security policy rejections
kubectl describe pod -l app=oci-modified
```

> [!TIP]
> If your namespace enforces the `restricted` Pod Security Standard and there are non-compliant settings (such as missing `runAsNonRoot` or un-dropped capabilities), `kubectl describe pod` will show warning events from the `pod-security` admission controller.

Check the application logs:
```sh
kubectl logs -l app=oci-modified -f
```

Verify that the `ConfigMap` file and persistent storage mounted properly inside the pod:
```sh
kubectl exec -it deployment/oci-modified -- cat /app/template.txt
kubectl exec -it deployment/oci-modified -- ls -la /tmp/data
```

Verify network access via port-forwarding:
```sh
kubectl port-forward svc/template-service 8080:8080
# In another terminal:
curl http://localhost:8080
```

#### 5. Uninstalling from the Talos Cluster

When testing is complete, clean up the release:
```sh
mise run helm-u
# or: helm uninstall test
```

---

## Mise Tasks Quick Reference

All testing, linting, and lifecycle operations are conveniently accessible through `mise`:

| Mise Task | Command | Description |
|---|---|---|
| `mise run compose` | `podman compose up -d --build` | Build and run the modified image in Podman Compose |
| `mise run down` | `podman compose down` | Stop and remove the modified Podman Compose stack |
| `mise run play` | `podman play kube rendered.yaml` | Render chart and run manifests locally via Podman Play Kube |
| `mise run play-d` | `podman play kube rendered.yaml --down` | Teardown the Podman Play Kube deployment |
| `mise run logs` | `podman compose logs -f` | Follow logs from the Podman Compose stack |
| `mise run helm-d` | `helm dependency build chart/` | Update and build Helm chart dependencies |
| `mise run helm-l` | `helm lint chart/` | Lint the Helm chart for errors |
| `mise run helm-t` | `helm template test chart/ > rendered.yaml` | Render Helm templates to `rendered.yaml` |
| `mise run helm-i` | `helm install test chart/` | Install the Helm chart to the current Kubernetes cluster |
| `mise run helm-u` | `helm uninstall test` | Uninstall the Helm chart release from the cluster |
| `mise run hk` | `hk check --all` | Run all repository pre-commit and formatting checks |
| `mise run trivy-fs` | `trivy fs .` | Scan repository filesystem for security vulnerabilities |
| `mise run trivy-i` | `trivy image ghcr.io/joeckr/oci-modified:test` | Scan the built container image with Trivy |

---

## Getting Started

1. **Use as a Template**
   Clone or use this repository as a template for your own project.

2. **Modify the Dockerfile**
   Update the `Dockerfile` to base it on your desired open-source image. Ensure that you maintain the non-root user configurations and adjust permissions for any directories your application needs to write to (e.g., using `chgrp -R 0` and `chmod -R g+rwX`).

3. **Update the Helm Chart**
   Navigate to the `chart/` directory and update `Chart.yaml`, `values.yaml`, and the templates to reflect your application's specifics. Choose between Ingress (`ingress.route: "false"`) for Talos/vanilla Kubernetes or Route (`ingress.route: "true"`) for OpenShift.

4. **Configure Build Versions**
   Update `versions.json` with the upstream image versions you wish to build.

5. **Run the Test Suite**
   Validate changes through the 4-tier process: upstream compose (baseline failure), `mise run compose` (fixed local), `mise run play` (manifest test), and `mise run helm-i` (Talos cluster test).

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
