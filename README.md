# jq-controller

[![Docker](https://github.com/rozcietrzewiacz/jq-controller/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/rozcietrzewiacz/jq-controller/actions/workflows/docker-publish.yml)

A generic kubernetes controller based on jq. Quickly prototype your own operators using [jq filters](https://github.com/stedolan/jq)!

The controller will `kubectl apply` whatever comes as a result of applying the `jq` filter on the input resource(s) you specify. 


### how it works
To give you a general idea of what it does, below is a simplified view of `jq-controller` operation flow:

```shell
kubectl get --watch ${WATCH_TARGET} -o json \
| jq <your transform filter> \
| kubectl apply -f -
```

So, for example, if you specify:

 - `WATCH_TARGET=configmap/jq-input`
 - content of `configmap/jq-input`:
 ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: jq-input
  data:
    var: Whatever, really
 ```
 - the value of your `jq` filter:
 ```json
  {
     "apiVersion": "v1",
     "kind": "ConfigMap",
     "metadata": {
         "name": "jq-output"
     },
     "data": {
         "extracted": .var
     }
  }
 ```

then the controller will create the following `configmap`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jq-output
data:
  extracted: Whatever, really
```

And this is what the manifests under [examples/privileged-insecure/](examples/privileged-insecure/) will actually do if you `kubectl apply` them :)
