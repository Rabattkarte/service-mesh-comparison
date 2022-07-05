#!/bin/bash
# set -x

# Source common lib
. ./_common.sh

check_tools minikube kubectl

# Variables
MK_PROFILE_NAME="${MK_PROFILE_NAME:-cilium-kube}"
DEMO_NAMESPACE="${DEMO_NAMESPACE:-demo-galaxy}"

# Set minikube profile to the defined profile
minikube profile "$MK_PROFILE_NAME"

# Create a namespace for our demo deployment
kubectl create namespace "$DEMO_NAMESPACE" \
  --dry-run=client \
  --output yaml |
  kubectl apply --filename -

# Deploy resources deathstar, xwing, tiefighter
kubectl apply \
  --filename "https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/http-sw-app.yaml" \
  --namespace "$DEMO_NAMESPACE" \
  --wait=true

# Wait for our resources to be Ready
kubectl wait deploy --all --for=condition=Available \
  --namespace "$DEMO_NAMESPACE"
kubectl wait po --all --for=condition=Ready \
  --namespace "$DEMO_NAMESPACE"

# Get deployed resources
kubectl get deploy,po,svc \
  --namespace "$DEMO_NAMESPACE"

# Get the main cilium pod
CILIUM_POD=$(kubectl get pods \
  --namespace kube-system \
  --selector k8s-app=cilium \
  --no-headers=true \
  -o custom-columns=":metadata.name")

# List all cilium endpoints. This should include our galaxy.
kubectl exec "$CILIUM_POD" \
  --namespace kube-system \
  -- cilium endpoint list
