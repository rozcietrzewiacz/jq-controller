#!/bin/bash
kubectl get -f bundle.list.jsonl -o yaml \
| yq -P '.items[]
	| .metadata |=
		( del(.annotations)
		| del(.uid)
		| del(.creationTimestamp)
		| del(.resourceVersion)
		| del(.generation)
		)
	| del(.status)
	| del(.secrets)' \
| sed 's/^apiVersion/---\n\0/' \
> jq-controller-bundle.yaml

wc -l jq-controller-bundle.yaml
