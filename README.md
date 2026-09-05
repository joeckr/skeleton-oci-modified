# oci-skeleton

This project exists as a template for those who want to create their own images.

Most of the images I create are OpenShift compliant and may also include some nice to have features.

This repo just has an NGINX image that gets built to serve as a template.

This template includes:

- Dockerfile

- Docker Compose

- Helm Chart

- GitHub CI Workflows:

  - Builds and pushes images based on `versions.json` (Uses CI Template)
