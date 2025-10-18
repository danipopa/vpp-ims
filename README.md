ims-vpp — VPP + Multus deployment helper

This folder contains Kubernetes manifests and host helper scripts to deploy FD.io VPP and Multus CNI on a Kubernetes cluster, and to create two host veth interfaces that VPP can bind.

Files added
- k8s/multus-daemonset.yaml — Multus DaemonSet, ServiceAccount and RBAC (install Multus CNI)
- k8s/vpp-configmap.yaml — ConfigMap with simple `vpp.conf` for the VPP container
- k8s/vpp-daemonset.yaml — VPP DaemonSet and ServiceAccount; mounts host /sys and /dev
- scripts/create_veths.sh — host script to create two veth pairs for testing

Prerequisites
- A Linux host with sudo/root access
- A Kubernetes cluster (kubeconfig set in environment)
- kubectl configured to point at the cluster
- Kernel modules required by DPDK/VPP may be needed (vfio, uio, igb_uio). Running VPP in containers may require privileged containers and host device mounts.

Quick deploy
1. Create two host veth pairs for VPP to use (run on the node(s) where VPP DaemonSet will run):

```bash
sudo bash ./scripts/create_veths.sh
```

2. Install Multus and VPP to the cluster (apply manifests):

```bash
kubectl apply -f k8s/multus-daemonset.yaml
kubectl apply -f k8s/vpp-configmap.yaml
kubectl apply -f k8s/vpp-daemonset.yaml
```

Notes and verification
- The VPP DaemonSet runs privileged and mounts host /sys and /dev; this is required for DPDK access but increases attack surface. Consider NodeSelector or tolerations to control which nodes run VPP.
- To verify VPP sees host interfaces, exec into the vpp pod and run `vppctl show hardware` or `ip link`.

Example: find a VPP pod and exec:

```bash
POD=$(kubectl get pods -n kube-system -l app=vpp -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system -it $POD -- bash
# inside pod
vppctl show interfaces
```

Caveats and next steps
- The provided manifests are minimal and intended for lab/testing only. For production, pin images, tune securityContext, use proper CNI configuration and DaemonSet node selectors.
- If you want VPP inside the container to bind the host veths directly, you can leave the host-end of the veths (e.g. `veth-host-a`) on the host and inside the pod mount the host network and use `veth-host-a` name. Alternatively, use Multus to attach interfaces into pods and use VPP's host-interface plugin.

If you'd like, I can:
- Add a Kubernetes NetworkAttachmentDefinition for Multus and a sample pod that receives a secondary interface
- Add a systemd unit or kubelet init script to ensure veth creation on node boot
- Make the VPP DaemonSet assign specific interface names using a startup-config

Image pull from GHCR / private registries
---------------------------------------
If you host VPP in GHCR or another private registry, create an image-pull secret in the `kube-system` namespace and either reference it from the DaemonSet (`imagePullSecrets` in the pod spec) or attach it to the `vpp` ServiceAccount:

```bash
# Create the secret (example for GHCR using username and a personal access token as password)
kubectl create secret docker-registry ghcr-creds \
	--docker-server=ghcr.io \
	--docker-username=<your-username> \
	--docker-password=<your-token> \
	--docker-email=<you@example.com> -n kube-system

# Patch the vpp serviceaccount to use the secret
kubectl patch serviceaccount vpp -n kube-system -p '{"imagePullSecrets": [{"name": "ghcr-creds"}]}'
```

After that delete the failing vpp pod and the DaemonSet will recreate pods that use the secret to pull images.

