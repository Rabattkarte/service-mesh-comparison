#!/bin/bash
set -x

# Check for all necessary tools
for tool in minikube \
  cilium \
  helm; do
  if ! command -v $tool &>/dev/null; then
    printf "'%s' could not be found. Aborting.\n" "$tool"
    exit
  fi
done

# Variables
MK_PROFILE_NAME="${MK_PROFILE_NAME:-cilium-kube}"
MK_MEMORY="${MK_MEMORY:-2g}"
API_SERVER_PORT="8443"
CILIUM_HELM_REPO="https://helm.cilium.io/"
CILIUM_VERSION="1.12.0-rc3"
HUBBLE_VERSION="0.9.0"

# Create a new minikube profile
minikube start \
  --network-plugin="cni" \
  --cni="false" \
  --extra-config="kubeadm.skip-phases=addon/kube-proxy" \
  --addons="metrics-server,metallb" \
  --memory="$MK_MEMORY" \
  --apiserver-port="$API_SERVER_PORT" \
  --profile="$MK_PROFILE_NAME"

# Set minikube profile to the just create profile
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

# kubectl -n kube-system get pods --watch
# sleep 60

# Restart all pods not yet managed by Cilium
(
  IFS=$'\n'
  PODS_TO_RESTART=$(kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true |
    grep '<none>' |
    awk '{print "-n "$1" "$2}')

  for pod in $PODS_TO_RESTART; do
    cmd="kubectl delete pod $pod"
    eval "$cmd"
  done
)

#  |
# xargs -L 1 -r kubectl delete pod

printf "Exporting 'MINIKUBE_PROFILE=%s\n'" "$MK_PROFILE_NAME"
export MINIKUBE_PROFILE="$MK_PROFILE_NAME"
