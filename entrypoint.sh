#!/bin/bash

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET ]]; then
	echo "EMAIL, DOMAINS and SECRET env vars required"
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

cat $HOME/secret-patch-template.json | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${SECRET}/" | \
	sed "s/TLSCERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TLSKEY/$(cat ${CERTPATH}/privkey.pem |  base64 | tr -d '\n')/" \
	> $HOME/secret-patch.json

cat $HOME/secret-patch.json || exit 1

# update secret
curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k -v -XPATCH  -H "Accept: application/json, */*" -H "Content-Type: application/strategic-merge-patch+json" -d @$HOME/secret-patch.json https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET}