# Astarte Cluster GitHub Action

[![](https://github.com/astarte-platform/astarte-cluster-action/workflows/Test/badge.svg?branch=master)](https://github.com/astarte-platform/astarte-cluster-action/actions)

A GitHub Action that creates a local [Astarte](https://github.com/astarte-platform/astarte) cluster for testing application against it.

## Using the Cluster

The action will create a new Cluster which will be exposed at `api.autotest.astarte-platform.org` (APIs) and `broker.autotest.astarte-platform.org` (broker).
The action takes care of all the plumbing needed for the domains to be resolved against the cluster. Both domains have a valid SSL certificate, and by all
means the resulting enviroment is equivalent to a vanilla production one - as such, all Astarte tooling (SDKs, CLIs...) will work as expected when pointed
to `api.autotest.astarte-platform.org` as the Cluster endpoint.

The action also sets up [astartectl](https://github.com/astarte-platform/astartectl) with a context already configured to operate on the new Cluster and
Realm and in your `$PATH`. As such, you can immediately use commands such as `astartectl pairing agent register` to set up your own devices for testing.

The Housekeeping key and the Realm key (the action will create an empty realm for convenience) can be retrieved from the `housekeeping_key` and `realm_key`
outputs respectively, or through `astartectl`. API Tokens can ben generated using `astartectl utils gen-jwt`.

For any information on how to use the Astarte Cluster itself, please refer to the [Astarte Documentation](https://docs.astarte-platform.org/latest/).

## Usage

### Pre-requisites

This action creates a local Kubernetes environment using [KinD](https://kind.sigs.k8s.io/) through the
[@container-tools/kind-action](https://github.com/container-tools/kind-action) GitHub Action.
As such, when using this action, the runner must be running Linux and a Kubernetes environment will be created and owned by the Astarte Cluster.

The Action will bind ports `80`, `443` and `8883` on the host, where APIs and Broker will be exposed. As such, those ports should not be used by
other services in other steps.

Create a workflow YAML file in your `.github/workflows` directory. An [example workflow](#example-workflow) is available below.
For more information, reference the GitHub Help Documentation for [Creating a workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file).

### Inputs

- `astarte_chart_version`: The Helm chart version for Astarte Operator. Defaults to the last one in the 22.11.xx series.
- `astarte_version`: The Astarte version to install. Defaults to `1.1.0`.
- `astarte_realm`: The Astarte Realm that will be created with the cluster. Defaults to `test`.
- `astarte_namespace`: The Kubernetes namespace where Astarte will be installed. Defaults to `astarte`.
- `kind_version`: The kind version to use (default: `v0.11.1`). Advised to leave as default.
- `kind_node_image`: The Docker image for the cluster nodes. Advised to leave as default.

### Outputs

- `housekeeping_key`: The Housekeeping private key for the newly created Astarte Cluster.
- `realm_key`: The Realm private key.

If you need to interact with the cluster to e.g. register a device, the simplest and advised way is to simply use `astartectl`.

### Example Workflow

Create a workflow (eg: `.github/workflows/create-cluster.yml`):

```yaml
name: Create Astarte Cluster

on: pull_request

jobs:
  create-cluster:
    runs-on: ubuntu-latest
    steps:
      - name: Create Astarte Cluster
        uses: astarte-platform/astarte-cluster-action@v1
```

This uses [@astarte-platform/astarte-cluster-action](https://github.com/astarte-platform/astarte-cluster-action) GitHub Action to spin up an [Astarte](https://github.com/astarte-platform/astarte) Kubernetes cluster on every Pull Request.
