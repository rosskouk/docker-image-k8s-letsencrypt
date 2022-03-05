#!/bin/bash

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET ]]; then
	echo "EMAIL, DOMAINS and SECRET env vars are required!"
	env
	exit 1
fi

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

cd $HOME
python3 -m http.server --directory $HOME/http-root 80 &
PID=$!

# Uses the LE staging server
certbot -v --test-cert certonly --webroot -w $HOME/http-root -n --agree-tos --email ${EMAIL} --no-self-upgrade -d ${DOMAINS}

# Uses the LE production server - this is rate limited quickly do not use for testing!
#certbot certonly --webroot -w $HOME/http-root -n --agree-tos --email ${EMAIL} --no-self-upgrade -d ${DOMAINS}

kill $PID

CERTPATH=/etc/letsencrypt/live/$(echo $DOMAINS | cut -f1 -d',')

ls $CERTPATH || exit 1

cat $HOME/tpl-secret.json | \
	sed "s/TPL_NAMESPACE/${NAMESPACE}/" | \
	sed "s/TPL_SECRET_NAME/${SECRET}/" | \
	sed "s/TPL_TLS_CERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TPL_TLS_KEY/$(cat ${CERTPATH}/privkey.pem |  base64 | tr -d '\n')/" \
	> $HOME/secret-patch.json

# update secret
secret_update=$(curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
					 -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
					 -H "Accept: application/json, */*" \
					 -H "Content-Type: application/strategic-merge-patch+json" \
					 -d @$HOME/secret-patch.json \
					 -X PATCH https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET} | \
				grep code | \
		        awk -F ':' '{print $2}' | \
		        xargs
			   )

# Ensure $secret_update is NULL
if [ -z $secret_update ]
then
	echo "Secret updated"
	exit 0

else
	echo "An error occurred while updating the secret"
	exit 1
fi