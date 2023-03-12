def chown( kind; name; uid ):
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
#################################

## TODO: 
# | pod( controller )
# , cm( filter )
# , cm( controller )
# , rbac( sa, output.affectedObjectTypes )

|
(
  {
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
      "labels": {
        "jq": "controller",
        "operator": $name
      },
      #"namespace": $target.namespace,
      #"ownerReferences": [{
      #    "apiVersion": .apiVersion,
      #    "kind": .kind,
      #    "name": $name,
      #    "blockOwnerDeletion": true,
      #  }],
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
            { "name": "filter",  "mountPath": "/in" }
          ],
          "env": [
            { "name": "TRANSFORM_DEF_FILE", "value": "/in/filter.jq" },
            { "name": "WATCH_TARGET",       "value": ($target.kind + "." + $target.apiGroup) },
            { "name": "WATCH_EVENTS",       "value": "ADDED, MODIFIED" },
            { "name": "WATCH_MASK",         "value": "." }
          ]
        }],
      "restartPolicy": "Always",
      "volumes": [
        { "name": "scripts", "configMap": { "defaultMode": 420, "name": "jq-controller" }},
        { "name": "filter",  "configMap": { "defaultMode": 420, "name": $name }}
      ]
    } 
  }
  | chown(.kind, $name, .metadata.uid )
,
(
  cm( $name )
  | .data["filter.jq"] = $filter
)
