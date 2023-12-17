# Kubernetes / Deckhouse Cluster

[Deckhouse](https://deckhouse.io/) is an open-source Kubernetes platform that simplifies cluster management and extends Kubernetes functionality with
declarative configuration management, monitoring, and security features.

The Deckhouse installer is available as a Docker container image. It is based on the dhctl tool which we will use to create and configure objects in
the AWS cloud infrastructure.

## Prerequisites

You need to be sure that you have the AWS account set up as described in the [AWS](../aws/README.md) section.

## Configuration

To install Deckhouse we use two files:

* YAML file with the configuration (required).
* YAML file with resources to create after Deckhouse installation (optional).

> Note: See aws directory for configuration files used to setup the cluster.

Both files are included for the cluster with 1 master node and 1-3 worker nodes. We add two additional master nodes after installation.

> Important warning: Do not set master replica number to number other than 1, it will cause numerous issues within the AWS: duplicating IAM users,
> access keys, security groups, networks, load balancers and other resources which will require a lot of manual fixes to the AWS account itself which
> will take a lot of time and effort. So always start with a single master and scale only after the installation.

### SSH key

You may want to generate a new SSH key pair with `ssh-keygen -t rsa -b 4096 -v`, save private key (in this case, hereafter referred to
as `l7-aws-id_rsa.pem`) to the ~/.ssh directory and make the private key readonly with `chmod 400 l7-aws-id_rsa.pem`.

You will also require to update the `sshPublicKey` value of the `00-deckhouse-installation.yml` configuration file with the public SSH key.

## Installation

The command to pull the installer container from the Deckhouse public registry:

```shell
docker run --pull=always -it \
 -v "$PWD/kube/yaml/00-deckhouse-installation.yml:/config.yml" \
 -v "$HOME/.ssh/:/tmp/.ssh/" \
 -v "$PWD/kube/yaml/01-deckhouse-resources.yml:/resources.yml" \
 -v "$PWD/dhctl-tmp:/tmp/dhctl" \
 registry.deckhouse.io/deckhouse/ce/install:stable bash
```

> Note: This command can take some time to download the container image (about 800 MB).

The installation of Deckhouse in the installer container is performed using the dhctl tool:

> Note: Further commands are executed inside the installer container, not on the host machine.

```shell
dhctl bootstrap --ssh-user=ubuntu --ssh-agent-private-keys=/tmp/.ssh/l7-aws-id_rsa.pem --config=/config.yml --resources=/resources.yml
```

If the installation is interrupted, you can restart it. If installation fails, use the dhctl command to delete the cluster resources:

```shell
dhctl bootstrap-phase abort --ssh-user=ubuntu --ssh-agent-private-keys=/tmp/.ssh/l7-aws-id_rsa.pem --config=/config.yml
```

When the installation is complete, the installer will output the IP address of the master node. You will need it for further access to the cluster.

## Accessing the cluster

Connect to the master node via SSH using the private key and the IP address of the master node (see the previous step):

```shell
ssh -i ~/.ssh/l7-aws-id_rsa.pem ubuntu@<master-node-ip>
```

Check that the kubectl is working by listing a list of cluster nodes:

```shell
sudo kubectl get nodes
```

It may take some time to start the Ingress controller after installation. You can check the status of the Ingress controller with the following
command:

```shell
sudo -n d8-ingress-nginx get pods
```

Make sure that the Ingress controller is running by checking that the status of the pods is `Running`.

Also wait for the load balancer to become ready:

```shell
sudo kubectl -n d8-ingress-nginx get svc nginx-load-balancer
```

The EXTERNAL-IP value must be set to the public address or DNS name.

## DNS

To access the web interface of Deckhouse services, you need to:

* Configure DNS records for the cluster.
* Specify template for DNS names in the configuration file (already done in the provided configuration file).

> Note: DNS records must point to the load balancer of the Ingress controller, not directly to the master node.

### Wildcard DNS

If your cluster DNS name template is a wildcard DNS (e.g., *.cluster.le7el.com), then add a corresponding wildcard CNAME record containing the
hostname of load balancer. Run the following command on the master node to get the hostname of load balancer:

```shell
sudo kubectl -n d8-ingress-nginx get svc nginx-load-balancer -o json | jq -r '.status.loadBalancer.ingress[0].hostname'
```

### Subdomain DNS

If your cluster DNS name template is a subdomain DNS (e.g., cluster.le7el.com), then add corresponding A records containing the IP address of load
balancer (of CNAME records with its DNS) for each subdomain:

* api
* argocd
* cdi-uploadproxy
* dashboard
* deckhouse
* documentation
* dex
* grafana
* hubble
* istio
* istio-api-proxy
* kubeconfig
* openvpn-admin
* prometheus
* status
* upmeter

## Configure remote access to the cluster

On a local machine follow the following steps to configure the connection of `kubectl` to the cluster:

* Open [kubeconfig generator page](https://kubeconfig.infra.le7el.com).
* Login as a user registered in the cluster (provided in the configuration file during installation, you may also create a new user).
* Select the tab corresponding to your operating system.
* Follow the instructions on the page.
* Check that `kubectl` is working, for example by listing a list of cluster nodes (`kubectl get nodes`).

## Next steps

Configure Deckhouse services referring to the [documentation](https://documentation.cluster.le7el.com/).

### Adding master nodes

Start the installer container with the dhctl tool using DH_VERSION and DH_EDITION used for the cluster installation:

```shell
export DH_VERSION=$(kubectl -n d8-system get deployment deckhouse -o jsonpath='{.metadata.annotations.core\.deckhouse\.io\/version}') \
export DH_EDITION=$(kubectl -n d8-system get deployment deckhouse -o jsonpath='{.metadata.annotations.core\.deckhouse\.io\/edition}' | tr '[:upper:]' '[:lower:]' ) \
docker run --pull=always -it -v "$HOME/.ssh/:/tmp/.ssh/" \
registry.deckhouse.io/deckhouse/${DH_EDITION}/install:${DH_VERSION} bash
```

Edit Deckhouse configuration and set `masterNodeGroup.replicas` to 3 inside the installer container:

```shell
dhctl config edit provider-cluster-configuration --ssh-agent-private-keys=/tmp/.ssh/l7-aws-id_rsa.pem --ssh-user=ubuntu \
--ssh-host <MASTER-NODE-0-HOST>
```

Then run the following command to apply the changes and start scaling:

```shell
dhctl converge --ssh-agent-private-keys=/tmp/.ssh/l7-aws-id_rsa.pem --ssh-user=ubuntu --ssh-host <MASTER-NODE-0-HOST>
```

Wait until the required number of master nodes is ready and all `control-plane-manager` instances are up and running:

```shell
kubectl -n kube-system wait pod --timeout=10m --for=condition=ContainersReady -l app=d8-control-plane-manager
```

### Adding worker nodes

Run the following command to add a worker node (if you are running it on the master node, you would need to prepend it with sudo):

```shell
kubectl edit ng worker
```

In the spec:cloudInstances section, find minPerZone and maxPerZone and set them to the required values.

> Note: The that the cluster may not order and provision additional nodes if the capacity of the existing nodes is sufficient to meet the cluster
> requirements. You can increase the minPerZone value to force the cluster to order new nodes.

### Changing the cluster DNS

Execute this command to edit the global Deckhouse module configuration:

```shell
kubectl patch mc global --type merge -p "{\"spec\": {\"settings\":{\"modules\":{\"publicDomainTemplate\":\"%s.cluster.le7el.com\"}}}}"
```

## Troubleshooting

> **Error**: `multiple EC2 Subnets matched; use additional constraints to reduce matches to a single EC2 Subnet`
>
> **Solution**: Go to the AWS console, select the VPC, select the Subnets tab, and delete all subnets with the matching name (e.g. le7el-...).

> **Error**: `multiple EC2 Security Groups matched; use additional constraints to reduce matches to a single EC2 Security Group`
>
> **Solution**: Go to the AWS console, go to the Security Groups tab, and delete all security groups with the matching name (e.g. le7el-...), it may
> require to delete links between SG (in inbound/outbound rules) and other resources (e.g. EC2 instances).

> **Error**: `error importing EC2 Key Pair (le7el): InvalidKeyPair.Duplicate: The keypair already exists`
>
> **Solution**: Go to the AWS console and delete the key pair with the matching name (e.g. le7el).

> **Error**: `creating IAM instance profile le7el-node: EntityAlreadyExists: Instance Profile le7el-node already exists`
>
> **Solution**: Go to the AWS console and delete the instance profile with the matching name (e.g. le7el-node).

> **Error**: `failed creating IAM Role (le7el-node): EntityAlreadyExists: Role with name le7el-node already exists`
>
> **Solution**: Go to the AWS console and delete the role with the matching name (e.g. le7el-node).

> **Warning**: It can be hard to change the cluster publicDomainTemplate after installation, as it requires certificate, load balancer and other
> changes, which are unclear and may require manual intervention. It is recommended to set the correct value before installation.

## Destroying Cluster

To destroy the cluster (to provision a new one), run the following command from the installation container:

```shell
dhctl destroy --ssh-host=<MASTER-0-HOST> --ssh-user=ubuntu --ssh-agent-private-keys=/tmp/.ssh/l7-aws-id_rsa.pem
```
