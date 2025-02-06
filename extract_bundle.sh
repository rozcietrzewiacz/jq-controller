#!/bin/bash
kubectl get -f bundle.list.jsonl -o yaml \
| yq -P ".items[]|$(cat clean-k8s-obj.jq)" \
| sed 's/^apiVersion/---\n\0/' \
> jq-controller-bundle.yaml

wc -l jq-controller-bundle.yaml
