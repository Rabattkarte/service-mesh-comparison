# service-mesh-comparison

## Prerequisites

- minikube
- Docker driver for minikube must be enabled
- cilium >= v1.12.0
- `cilium-cli`
- `helm` >= 3.0.0

## Setup Cilium Service Mesh in `minikube`

We are following the `latest` docs:

- for [getting started](https://docs.cilium.io/en/latest/gettingstarted/k8s-install-default/)
- and [Helm installation](https://docs.cilium.io/en/latest/gettingstarted/k8s-install-helm/)

Let's go.

1. Create a new minikube profile

   ```sh
   minikube start \
     --network-plugin=cni \
     --cni=false \
     --addons=metrics-server \
     --profile='service-mesh-cilium2'
   ```

   and enable the `metrics-server` addon

   ```sh
   minikube addons enable metrics-server -p service-mesh-cilium
   ```

   and ensure, that you are connecting to the right context:

   ```sh
   kubectl config current-context
   ```

1. Add Cilium's Helm repo and install a **version >= v1.12.0**

   ```sh
   helm repo add cilium https://helm.cilium.io/
   helm repo update cilium
   ```

   ```sh
   helm upgrade \
     --install cilium cilium/cilium \
     --version 1.12.0-rc3 \
     --set operator.replicas=1 \
     --namespace=kube-system
   ```

1. Restart all unmanaged pods

   ```sh
   kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true | grep '<none>' | awk '{print "-n "$1" "$2}' | xargs -L 1 -r kubectl delete pod
   ```

1. Validate installation

   ```sh
   # kubectl -n kube-system get pods --watch
   kubectl create ns cilium-test
   kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/connectivity-check/connectivity-check.yaml
   kubectl get pods -n cilium-test # everything should be in state "Running"
   ```

   If everything runs, let's clean up again by removing the namespace.

   ```sh
   kubectl delete ns cilium-test
   ```
