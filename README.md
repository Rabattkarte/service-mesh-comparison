# service-mesh-comparison

## Prerequisites

- `Docker Desktop`
- `minikube`
  - Docker driver for minikube must be enabled
- `cilium` >= v1.12.0
- `helm` >= 3.0.0
- `cilium-cli`
- `hubble-cli`

## Setup Cilium Service Mesh in `minikube`

We are following the `latest` docs:

- for [getting started](https://docs.cilium.io/en/latest/gettingstarted/k8s-install-default/)
- and [Helm installation](https://docs.cilium.io/en/latest/gettingstarted/k8s-install-helm/)

Let's go.

1. Start Docker Desktop.
1. Make **docker** the default driver for **minikube**: `minikube config set driver docker`.
1. Execute [00_install_cilium_in_minikube.sh](./00_install_cilium_in_minikube.sh) to provision a minikube profile with Cilium CNI / Service Mesh / Hubble.

   ```sh
   ./00_install_cilium_in_minikube.sh
   ```
