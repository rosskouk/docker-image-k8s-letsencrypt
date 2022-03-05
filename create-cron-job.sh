#!/bin/bash

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET || -z $JOB_NAME]]; then
	echo "EMAIL, DOMAINS, SECRET and JOB_NAME env vars are required!"
	env
	exit 1
fi

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)


#sed "s/TPL_NAMESPACE/${NAMESPACE}/" | \

cat $HOME/tpl-cron-job.json | \
	sed "s/TPL_CRON_NAME/${JOB_NAME}/" | \
	sed "s/TPL_CRON_CRONTAINER_NAME/${SECRET}-cronjob"
	sed "s/TPL_DOMAINS/${DOMAINS}/" | \
	sed "s/TPL_EMAIL/${EMAIL}/" | \
	sed "s/TPL_SECRET_NAME/${SECRET}/" \
	> $HOME/job-patch.json

cat $HOME/job-patch.json || exit 1

# Create cron job
#curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k -v -XPATCH  -H "Accept: application/json, */*" -H "Content-Type: application/strategic-merge-patch+json" -d @$HOME/secret-patch.json https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET}