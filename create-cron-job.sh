#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Check if cronjob already exists

cron_job_status=$(curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
	            	   -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
		               -X GET https://kubernetes/apis/batch/v1/namespaces/${NAMESPACE}/cronjobs/${SECRET}-cronjob/ | \
		     	  grep code | \
		     	  awk -F ':' '{print $2}' | \
		     	  xargs
	        	)

if [[ -z $cron_job_status ]]
then
	echo "Job already exists, nothing to do"
	exit 0

elif [[ $cron_job_status -eq 404 ]]
then
	if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET || -z $SERVICE_ACCOUNT || -z $SERVICE_FIELD || -z $SERVICE_NAME ]]
	then
		echo "EMAIL, DOMAINS, SECRET, SERVICE_ACCOUNT, SERVICE_FIELD and SERVICE_NAME env vars are required!"
		env
		exit 1
	fi
	echo "Cron job does not exist, preparing...."

	sleep 30

	# Fill in the cron job template
	cat $HOME/tpl-cron-job.json | \
	sed "s/TPL_SERVICE_FIELD/${SERVICE_FIELD}/" | \
	sed "s/TPL_SERVICE_NAME/${SERVICE_NAME}/" | \
	sed "s/TPL_SERVICE_ACCOUNT/${SERVICE_ACCOUNT}/" | \
	sed "s/TPL_CRON_NAME/${SECRET}-cronjob/" | \
	sed "s/TPL_CRON_CONTAINER_NAME/${SECRET}-certbot/" | \
	sed "s/TPL_DOMAINS/${DOMAINS}/" | \
	sed "s/TPL_EMAIL/${EMAIL}/" | \
	sed "s/TPL_SECRET_NAME/${SECRET}/" \
	> $HOME/cron-job-patch.json

	# Create the cron job
	cron_job_create=$(curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
			               -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
					       -H "Content-Type: application/json" \
					       -d @$HOME/cron-job-patch.json \
					       -X POST https://kubernetes/apis/batch/v1/namespaces/${NAMESPACE}/cronjobs/ | \
				      grep code | \
		              awk -F ':' '{print $2}' | \
		              xargs
				    )

	# Ensure $cron_job_create is NULL
	if [[ -z $cron_job_create ]]
	then
		echo "Cron job created"

	else
		echo "An error occurred while creating the cron job"
		echo $cron_job_create
		exit 1
	fi

	# Create one time job to generate secret immediately

	# Fill in the init job template
	cat $HOME/tpl-init-job.json | \
	sed "s/TPL_SERVICE_FIELD/${SERVICE_FIELD}/" | \
	sed "s/TPL_SERVICE_NAME/${SERVICE_NAME}/" | \
	sed "s/TPL_SERVICE_ACCOUNT/${SERVICE_ACCOUNT}/" | \
	sed "s/TPL_JOB_NAME/${SECRET}-init/" | \
	sed "s/TPL_JOB_CONTAINER_NAME/${SECRET}-certbot-init/" | \
	sed "s/TPL_DOMAINS/${DOMAINS}/" | \
	sed "s/TPL_EMAIL/${EMAIL}/" | \
	sed "s/TPL_SECRET_NAME/${SECRET}/" \
	> $HOME/init-job-patch.json

	init_job_create=$(curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
			               -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
					       -H "Content-Type: application/json" \
					       -d @$HOME/init-job-patch.json \
					       -X POST https://kubernetes/apis/batch/v1/namespaces/${NAMESPACE}/jobs/ | \
				 	  grep code | \
		         	  awk -F ':' '{print $2}' | \
		         	  xargs
					)

	# Ensure $init_job_create is NULL
	if [[ -z $init_job_create ]]
	then
		echo "Init job created"

	else
		echo "An error occurred while creating the init job"
		echo $init_job_create
		exit 1
	fi

	sleep 30

	# Check init job completed successfully
	init_job_status=$(curl -vk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
	                       -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
		          		   -X GET https://kubernetes/apis/batch/v1/namespaces/${NAMESPACE}/jobs/${SECRET}-init/status | \
		     		  grep code | \
		     		  awk -F ':' '{print $2}' | \
		     		  xargs
	        		)





	# Delete one time job

else
	echo "An error occurred while checking if the cronjob exists"
	exit 1
fi