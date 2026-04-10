# Astarte Cluster GitHub Action

[![](https://github.com/astarte-platform/astarte-cluster-action/workflows/Test/badge.svg?branch=master)](https://github.com/astarte-platform/astarte-cluster-action/actions)

A GitHub Action that creates a local [Astarte](https://github.com/astarte-platform/astarte) cluster for testing application against it.

## Using the Cluster

The action will create a new Cluster which will be exposed at `api.autotest.astarte-platform.org` (APIs) and `broker.autotest.astarte-platform.org` (broker).
The action takes care of all the plumbing needed for the domains to be resolved against the cluster. Both domains have a valid SSL certificate, and by all
means the resulting environment is equivalent to a vanilla production one - as such, all Astarte tooling (SDKs, CLIs...) will work as expected when pointed
to `api.autotest.astarte-platform.org` as the Cluster endpoint.

The action also sets up [astartectl](https://github.com/astarte-platform/astartectl) with a context already configured to operate on the new Cluster and
Realm and in your `$PATH`. As such, you can immediately use commands such as `astartectl pairing agent register` to set up your own devices for testing.

The Housekeeping key and the Realm key (the action will create an empty realm for convenience) can be retrieved from the `housekeeping_key` and `realm_key`
outputs respectively, or through `astartectl`. API tokens can be generated using `astartectl utils gen-jwt`.

If `astarte_realm` is set to an empty string, realm creation and context creation are skipped, and `realm_key` is empty.

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

- `astarte_chart_version`: The Helm chart version for Astarte Operator. Default: `26.5.0-dev`.
- `astartectl_version`: The astartectl CLI version to install. Default: `24.5.3`.
- `astarte_version`: The Astarte version to install. Default: `1.3.0-rc.2`.
- `astarte_realm`: The Astarte Realm that will be created with the cluster. Default: `test`. If empty, no realm is created.
- `astarte_namespace`: The Kubernetes namespace where Astarte will be installed. Defaults to `astarte`.
- `kind_version`: The kind version to use (default: `v0.31.0`). Advised to leave as default.
- `kind_node_image`: The Docker image for the cluster nodes (default: `kindest/node:v1.33.7@sha256:d26ef333bdb2cbe9862a0f7c3803ecc7b4303d8cea8e814b481b09949d353040`).
- `cert-manager_version`: The cert-manager version to use (default: `v1.20.1`).
- `haproxy_version`: The HAProxy Helm Chart version to use (default: `v1.49.0`).
- `rabbitmq_cluster_operator_version`: The RabbitMQ Cluster Operator version to use (default: `v2.20.0`).
- `scylla_operator_version`: The Scylla Operator version to use (default: `v1.20.2`).

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
        id: create-astarte-cluster
        uses: astarte-platform/astarte-cluster-action@v1
        with:
          astarte_chart_version: v26.5.0
          astarte_version: v1.3.0
          astartectl_version: v24.5.3
          astarte_realm: "customrealm"
          astarte_namespace: "astarte-test-namespace"
      - name: Show output variables
        run: |
          echo "Realm Key:"
          echo "${{ steps.create-astarte-cluster.outputs.realm_key }}"
          echo "Housekeeping Key:"
          echo "${{ steps.create-astarte-cluster.outputs.housekeeping_key }}"
      - name: Interact with the cluster (via kubectl)
        run: |
          kubectl get pods -n astarte-test-namespace
      - name: Save housekeeping key to file
        run: |
          printf '%s' "${{ steps.create-astarte-cluster.outputs.housekeeping_key }}" > housekeeping_key.pem
      - name: Interact with the cluster (via astartectl)
        run: |
          astartectl housekeeping realms show "customrealm" --ignore-ssl-errors -u https://api.autotest.astarte-platform.org -k ./housekeeping_key.pem

```

As you can see from the example above, once the cluster is created, you can interact with it both through `kubectl` and `astartectl` as you would with a normal Astarte Cluster. The action takes care of all the plumbing needed to make the cluster available at `api.autotest.astarte-platform.org` and `broker.autotest.astarte-platform.org`, and to set up `astartectl` with a context configured to operate on the new Cluster and Realm.

This uses [@astarte-platform/astarte-cluster-action](https://github.com/astarte-platform/astarte-cluster-action) GitHub Action to spin up an [Astarte](https://github.com/astarte-platform/astarte) Kubernetes cluster on every Pull Request.

## Compatibility Matrix

| Astarte Cluster Action Version | Astarte Version     | Astarte Kubernetes Operator Version |
|:------------------------------:|:-------------------:|:-----------------------------------:|
| v1.2.0                         | v1.0 - v1.2.0       | v24.5                               |
| v1.2.0                         | v1.2.1 - v1.2.x     | v24.5.2                             |
| v1.3.0 (unreleased)            | v1.3+               | v26.5                               |
