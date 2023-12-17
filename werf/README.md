# Werf and GitLab Runner Installation and Configuration

[Werf](https://werf.io/documentation/) is an open-source tool that simplifies building, packaging, and deploying applications to Kubernetes clusters, providing a streamlined workflow
for container-based application development and deployment.

[GitLab Runner](https://docs.gitlab.com/runner/register/) is an open-source tool that executes CI/CD jobs defined in GitLab pipelines, allowing for automated building, testing, and deploying of
applications across various platforms and environments.

This guide provides step-by-step instructions for installing Werf and a shared GitLab Runner on a dedicated runner machine.

## Prerequisites

- A dedicated machine or virtual instance to serve as the runner machine (e.g. AWS EC2 instance or bare-metal server) with Linux (Ubuntu) and
  root/sudo access.
- Bash, Git, GPG and Docker installed on the runner machine.

## Installation Steps

Follow the steps below to install Werf and GitLab Runner:

1. **Install Werf**:

    - Install the latest version of Werf by running the following command.

      ```shell
      curl -sSL https://werf.io/install.sh | bash -s -- --ci
      ```

    - Restart your terminal session and verify the Werf installation by running `werf version` in your terminal to ensure it's properly configured.

2. **Install GitLab Runner**:

    - Add the GitLab Runner repository to your system by running the following command.

      ```shell
      curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
      ```
    - Install the latest version of GitLab Runner by running the following command.

      ```shell
      sudo apt-get install gitlab-runner
      ```

3. **Register GitLab Runner**:

   > Note: The Gitlab Runner must be installed on a separate machine from the GitLab instance.

   > Note: We will use an authentication token and a shared runner in our case, refer to official Gitlab documentation for additional information or
   options.

    - As an administrator of the Gitlab instance, on the top bar select **Main Menu** > **Admin**.
    - On the left sidebar select **CI/CD** > **Runners**.
    - Select **New instance runner**.
    - Select a platform.
    - Enter configuration for the runner (optional).
    - Select **Submit**.
    - Follow the instructions to register the runner from the terminal.

## Usage

### Deploying to different Kubernetes clusters

By default, werf deploys Kubernetes resources to the cluster set for the werf kubectl command. You can use different kube-contexts of a single
kube-config file (the default is $HOME/.kube/config) to deploy to different clusters with commands like within your Gitlab CI/CD pipeline:

```shell
werf converge --kube-context staging
werf converge --kube-context production
```

You can also set the $WERF_KUBE_CONTEXT environment variable for `werf converge`.

Another option is using different kube-config files for different clusters with commands:

```shell
werf converge --kube-config "$HOME/.kube/staging.config"  # or $WERF_KUBE_CONFIG=...
werf converge --kube-config-base64 "$KUBE_PRODUCTION_CONFIG_IN_BASE64"  # or $WERF_KUBE_CONFIG_BASE64=...
```
