# jq-controller

[![Docker](https://github.com/rozcietrzewiacz/jq-controller/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/rozcietrzewiacz/jq-controller/actions/workflows/docker-publish.yml)

A generic kubernetes operator leveraging the power of `jq`. Quickly prototype your own controllers using [jq filters](https://github.com/stedolan/jq)!

`jq-controller` simplifies the process of creating Kubernetes controllers for DevOps engineers. To get a fully-functional controller you only need to create a relatively simple Custom Resource called `JqController`. The business logic of your controller gets defined as a `jq` filter expression, allowing you to manipulate chosen k8s object, thus generating any set of output json manifests.

While jq-controller assumes a basic understanding of Kubernetes, it can take care of the mundane and error prone tasks outside of your controller's business logic, such as configuring object ownerships, labels, and RBAC.

Oh, and since it's written entirely in `jq` and `bash`, you don't need to worry about frequent language updates!

### how it works

To give a general idea of what it does, below is a simplified view of `jq-controller` operation flow:

```shell
kubectl get --watch ${WATCH_TARGET} -o json \
| jq 'filter_expression' \
| kubectl apply -f -
```

In other words, `jq-controller` will `kubectl apply` whatever comes as a result of applying the `jq` filter on the input resource you specify. Under the hood, `jq-controller` itself is an operator (written in `jq-controller` itself, of course) that watches `JqController` objects and creates custom controllers based on them.

### the `JqController` resource

See [examples/](examples/)

# Installation

```
kubectl apply -f https://raw.githubusercontent.com/rozcietrzewiacz/jq-controller/main/jq-controller-bundle.yaml
```

This will create a `jq-controller` operator in `jq-ctr` namespace.

