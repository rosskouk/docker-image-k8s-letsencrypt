#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Check if cronjob already exists

job_status=$(curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
	              -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
		          -X GET https://kubernetes/apis/batch/v1/namespaces/${NAMESPACE}/cronjobs/${SECRET}-cronjob/ | \
		     grep code | \
		     awk -F ':' '{print $2}' | \
		     xargs
	        )

if [ -z $job_status ]
then
	echo "Job already exists, nothing to do"
	exit 0

elif [ $job_status -eq 404 ]
then
	if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET ]]
	then
		echo "EMAIL, DOMAINS and SECRET env vars are required!"
		env
		exit 1
	fi

	echo "Cron job does not exist, creating...."

	# Fill in template
	cat $HOME/tpl-cron-job.json | \
	sed "s/TPL_CRON_NAME/${SECRET}-cronjob/" | \
	sed "s/TPL_CRON_CRONTAINER_NAME/${SECRET}-certbot/" | \
	sed "s/TPL_DOMAINS/${DOMAINS}/" | \
	sed "s/TPL_EMAIL/${EMAIL}/" | \
	sed "s/TPL_SECRET_NAME/${SECRET}/" \
	> $HOME/job-patch.json

	# Create the cron job
	job_create=$(curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
			          -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
					  -H "Content-Type: application/json" \
					  -d @$HOME/job-patch.json \
					  -X POST https://kubernetes/apis/batch/v1/namespaces/${NAMESPACE}/cronjobs/ | \
				 grep code | \
		         awk -F ':' '{print $2}' | \
		         xargs
				)

	# Ensure $job_create is NULL
	if [ -z $job_create ]
	then
		echo "Cron job created"
		exit 0

	else
		echo "An error occurred while creating the cron job"
		exit 1
	fi

else
	echo "An error occurred while checking if the cronjob exists"
	exit 1
fi

# Create job from cronjob

# Check completion

# Delete one time job