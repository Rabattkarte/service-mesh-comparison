#!/bin/bash
set -x

# Source common lib
. ./_common.sh

check_tools minikube cilium helm

# Variables
MK_PROFILE_NAME="${MK_PROFILE_NAME:-cilium-kube}"
MK_MEMORY="${MK_MEMORY:-3g}"
API_SERVER_PORT="8443"
CILIUM_HELM_REPO="https://helm.cilium.io/"
CILIUM_VERSION="1.12.0-rc3"
HUBBLE_VERSION="0.9.0"

# Create a new minikube profile
minikube start \
  --network-plugin="cni" \
  --cni="false" \
  --extra-config="kubeadm.skip-phases=addon/kube-proxy" \
  --addons="metrics-server" \
  --memory="$MK_MEMORY" \
  --apiserver-port="$API_SERVER_PORT" \
  --profile="$MK_PROFILE_NAME"

# Set minikube profile to the just created profile
minikube profile "$MK_PROFILE_NAME"

# Grab API server's IP address
API_SERVER_IP=$(minikube ip --profile cilium-kube)

# Add cilium Helm repo
helm repo add cilium "$CILIUM_HELM_REPO"
helm repo update cilium

# Load all cilium images into the minikube cluster
minikube image load \
  --profile="$MK_PROFILE_NAME" \
  --daemon=true \
  "quay.io/cilium/cilium:v${CILIUM_VERSION}" \
  "quay.io/cilium/hubble-relay:v${CILIUM_VERSION}" \
  "quay.io/cilium/operator-generic:v${CILIUM_VERSION}" \
  "quay.io/cilium/hubble-ui-backend:v${HUBBLE_VERSION}" \
  "quay.io/cilium/hubble-ui:v${HUBBLE_VERSION}"

# Install Cilium CNI with Hubble
# & enable Host-Reachable Services
# https://docs.cilium.io/en/latest/gettingstarted/host-services/#host-services
# & replace kube-proxy with Cilium
# https://docs.cilium.io/en/latest/gettingstarted/kubeproxy-free/
helm upgrade \
  --install cilium cilium/cilium \
  --version "$CILIUM_VERSION" \
  --set operator.replicas=1 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hostServices.enabled=true \
  --set kubeProxyReplacement=strict \
  --set ingressController.enabled=true \
  --set k8sServiceHost="$API_SERVER_IP" \
  --set k8sServicePort="$API_SERVER_PORT" \
  --namespace=kube-system \
  --wait \
  --wait-for-jobs

# Wait until our local k8s context was set to the new minikube profile
while [ "$(kubectl config current-context)" != "$MK_PROFILE_NAME" ]; do
  sleep 1
done

# Wait for cilium to be up and running
cilium status --wait

# Restart all pods not yet managed by Cilium
kubectl get pods \
  --all-namespaces \
  --output custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork \
  --no-headers=true |
  grep '<none>' |
  awk '{print "-n "$1" "$2}' |
  xargs -L 1 -r kubectl delete pod
