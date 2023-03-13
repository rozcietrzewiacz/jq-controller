def chown( api; kind; name; uid ):
  .metadata.ownerReferences = [
    {
      "apiVersion": api,
      "kind": kind,
      "name": name,
      "uid": uid,
      "blockOwnerDeletion": true,
    }
  ]
;

def cm ( name ):
  {
    "apiVersion": "v1",
    "kind": "ConfigMap",
    "metadata": {
      "labels": {
        "jq": "controller",
        "operator": name
      },
      "name": name
    },
    "data": {}
  }
;

.
| .metadata.name as $name
| .spec.transform.source as $src
| .spec.transform.filter as $filter
| .spec.transform."input".watchTarget as $target


|
(
  {
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
      "labels": {
        "jq": "controller",
        "operator": $name,
        "jq-ctr": $labelJqCtr
      },
      "name": $name
    },
    "spec": {
      "containers": [{
          "name": "ctr",
          "image": .spec.watcherConfig.image,
          "command": [
            "bash",
            "/ctr/controller.sh"
          ],
          "volumeMounts": [
            { "name": "scripts", "mountPath": "/ctr" },
            { "name": "extra",   "mountPath": "/extra" },
            { "name": "filter",  "mountPath": "/in" }
          ],
          "env": [
            { "name": "TRANSFORM_DEF_FILE", "value": "/in/filter.jq" },
            { "name": "WATCH_TARGET",       "value": ($target.kind + "." + $target.apiGroup) },
            { "name": "WATCH_EVENTS",       "value": "ADDED, MODIFIED" },
            { "name": "WATCH_MASK",         "value": "." },
            { "name": "EXTRA_ARGS_PATH",    "value": "/extra" }
          ]
        }],
      "restartPolicy": "Always",
      "serviceAccount": "jq-adm",
    }
  }
  | .spec.volumes[0] =
    { "name": "scripts", "configMap": { "defaultMode": 420, "name": "jq-controller" }}
  | .spec.volumes[1] = { "name": "filter",  "configMap": { "defaultMode": 420, "name": $name }}
  | .spec.volumes[2] = { "name": "extra",   "projected": {
        "defaultMode": 420,
        "sources": [
          {
            "downwardAPI": {
              "items": [
                {
                  "fieldRef": {
                    "apiVersion": "v1",
                    "fieldPath": "metadata.labels['jq-ctr']"
                  },
                  "path": "labelJqCtr"
                },
                {
                  "fieldRef": {
                    "apiVersion": "v1",
                    "fieldPath": "metadata.namespace"
                  },
                  "path": "namespace"
                },
                {
                  "fieldRef": {
                    "apiVersion": "v1",
                    "fieldPath": "metadata.name"
                  },
                  "path": "podname"
                },
                {
                  "fieldRef": {
                    "apiVersion": "v1",
                    "fieldPath": "metadata.uid"
                  },
                  "path": "poduid"
                }
              ]
            }
          },
          {
            "configMap": {
              "name": "templates"
            }
          }
        ]
      }} #END projected volume
  | chown( "v1"; "Pod"; $podname; $poduid )
) #END Pod
,
(
  cm( $name )
  | .data["filter.jq"] = $filter
)
