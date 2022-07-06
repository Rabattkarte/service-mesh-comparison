#!/bin/bash
# set -x

#####
# This script is based off this tutorial:
# https://docs.cilium.io/en/latest/gettingstarted/servicemesh/http/
#####

# Source common lib
. ./_common.sh

check_tools minikube kubectl curl

# Variables
MK_PROFILE_NAME="${MK_PROFILE_NAME:-cilium-kube}"
ISTIO_DEMO_APP_MANIFEST="https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml"
INGRESS_MANIFEST="https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/basic-ingress.yaml"

case $1 in
"create")
  # Set minikube profile to the defined profile
  minikube profile "$MK_PROFILE_NAME"

  # This is just deploying the Istio demo app; it's not adding any Istio components
  kubectl apply \
    --filename "$ISTIO_DEMO_APP_MANIFEST" \
    --wait=true

  # This is deploying an example Cilium-backed Ingress
  kubectl apply \
    --filename "$INGRESS_MANIFEST" \
    --wait=true

  # Wait for our resources to be Ready
  kubectl wait deploy --all --for=condition=Available
  kubectl wait po --all --for=condition=Ready

  lb=$(kubectl get ingress basic-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  curl -s -v --connect-timeout 5 --max-time 20 --retry 3 --fail -- http://"$lb"
  curl -s -v --connect-timeout 5 --max-time 20 --retry 3 --fail -- http://"$lb"/details/1
  ;;

"delete")
  # Set minikube profile to the defined profile
  minikube profile "$MK_PROFILE_NAME"

  # This is deleting the Istio demo app
  kubectl delete \
    --filename "$ISTIO_DEMO_APP_MANIFEST" \
    --wait=true

  # This is deleting the example Cilium-backed Ingress
  kubectl delete \
    --filename "$INGRESS_MANIFEST" \
    --wait=true
  ;;

*)
  printf "Please specify either: %s create | delete\n" "$(basename "$0")"
  exit 1
  ;;
esac
