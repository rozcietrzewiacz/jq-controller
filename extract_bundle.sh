#!/bin/bash
kubectl create ns jq-ctr --dry-run=client -o yaml > jq-controller-bundle.yaml 
kubectl get \
	deployments.apps/jq-controller-operator \
	cm/jq-controller \
	cm/jq-controller-operator.jq \
	cm/lib.jq \
	cm/templates \
	sa/jq-adm \
	clusterrole/cluster-admin-jq \
	clusterrolebinding/cluster-admin-jq \
	crd/jqcontrollers.xxx.jq \
	-o yaml \
| yq -P '.items[]
	|.metadata |=
		( del(.annotations)
		| del(.uid)
		| del(.creationTimestamp)
		| del(.resourceVersion)
		| del(.generation)
		)
	|del(.status)' \
| sed 's/^apiVersion/---\n\0/' \
>> jq-controller-bundle.yaml

wc -l jq-controller-bundle.yaml
