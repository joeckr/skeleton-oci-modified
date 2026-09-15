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
- `docker-compose.yml`: For local testing and development.
- `versions.json`: Used by CI workflows to determine which versions of the image to build.
- `.github/workflows/`: CI/CD pipelines for building and pushing the images.

## Getting Started

1. **Use as a Template**
   Clone or use this repository as a template for your own project.

2. **Modify the Dockerfile**
   Update the `Dockerfile` to base it on your desired open-source image. Ensure that you maintain the non-root user configurations and adjust permissions for any directories your application needs to write to (e.g., using `chgrp -R 0` and `chmod -R g+rwX`).

3. **Update the Helm Chart**
   Navigate to the `chart/` directory and update `Chart.yaml`, `values.yaml`, and the templates to reflect your application's specifics.

4. **Configure Build Versions**
   Update `versions.json` with the upstream image versions you wish to build.

## License

Please refer to the `LICENSE` file for details.
