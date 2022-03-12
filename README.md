# K8S Let's Encrypt!

A K8s pod to enable automatic update of Kubernetes tls-secrets for use with an ingress.

Based on work by [Seth Jennings](https://github.com/sjenning/kube-nginx-letsencrypt.git) this is a sidecar container which allows container based
applications running on Kubernetes to use free TLS certificates provided by Let's Encrypt.

The container is based on Alpine Linux 3.15 and contains all tools required at a total size less than 90MB.


## Requirements

This container updates Kubernetes TLS secrets used by ingress controllers.  In order to use the container as presented, your application must be publically accessible over https via an ingress controller.  TLS can be enabled with a regular self signed certificate which will be replaced with a Let's Encrypt certificate by this container.


## What The Container Does

The K8s Lets Encrypt container is run in a Kubernetes pod along side the application container.  It contains two scripts:
  - create-cron-job.sh
  - create-secret.sh

The create-cron-job script creates a Kubernetes Cron Job which will update the application's TLS certificate on the 1st day of each month.  The script also creates a standard one time job which creates the certificate initially, allowing it to be renewed by the cron job when it runs.

The create-secret script runs certbot to get the certificate then adds it to a TLS secret for use by the ingress controller.

## Configuration

The container is completely configured via environment variables, these should be set when defining the InitContainer in your applications controller.
  - DOMAINS
    - A comma separated list of domains which the Let's Encrypt certificate should apply to.
  - EMAIL
    - Your e-mail address, this is required by Let's Encrypt.
  - SECRET
    - The name of the existing TLS secret that will be updated.
  - SERVICE_FIELD
    - The field name you use for labels and selectors
  - SERVICE_NAME
    - The name of the service which allows access to the application and K8S Let's Encrypt Container
  - SERVICE_ACCOUNT
    - The name of the service account with permissions to update the secret.

## Testing

The container is set by default to use the production Let's Encrypt API.  This is not suitable for testing as the volume of allowed requests is low before a temporary ban occurs.  When testing the container review the create-secret.sh script and switch to the test LE API.

## How To Use the Container

  1. Add port 80 to your applications service manifest for use by the K8S Lets Encrypt container
```yaml
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: webapp
    labels:
      com.example.service: webapp
  spec:
    type: ClusterIP
    ports:
      - name: "webapp-api"
        port: 3232
        targetPort: 3232
      - name: "certbot"
        port: 80
        targetPort: 80
    selector:
      com.example.service: webapp
```

  2. Create a service account, role and role binding.  This give the container the permissions required to update the TLS secret.
```yaml
  ---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: webapp
    namespace: default
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: webapp-tls-certs
    namespace: default
  rules:
    - apiGroups: [""]
      resources:
        - secrets
      resourceNames:
        - webapp-tls
      verbs: ["get", "patch"]

    - apiGroups: ["batch"]
      resources:
        - jobs
        - jobs/status
        - cronjobs
      verbs: ["get", "create", "delete"]
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: webapp-tls-certs
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: webapp-tls-certs
  subjects:
    - kind: ServiceAccount
      name: webapp
      namespace: default
```
  3. Create a TLS secret.  This should be a standard self signed certificate and is only really used to allow the ingress to be created.  This secret will be updated with the correct certificate by the container.
```yaml
  ---
  apiVersion: v1
  kind: Secret
  metadata:
    name: webapp-tls
  type: kubernetes.io/tls
  data:
    tls.crt: |
      xxxxxxxx
    tls.key: |
      xxxxxxxx
```
  4. Configure the ingress.  This directs challenge responses sent to .well-known to the correct pod.
```yaml
  ---
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: webapp-ingress
    annotations:
      kubernetes.io/ingress.class: nginx
  spec:
    rules:
    - host: "app.webapp.com"
      http:
        paths:
        - pathType: Prefix
          path: "/"
          backend:
            service:
              name: webapp
              port:
                number: 3232
        - pathType: Prefix
          path: "/.well-known"
          backend:
            service:
              name: webapp
              port:
                number: 80
    tls:
    - secretName: webapp-tls
      hosts:
        - "app.webapp.com"
```
  5. Add the container as an InitContainer to your controller (Deployment, Stateful Set etc.)
```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: webapp
    labels:
      com.example.service: webapp
  spec:
    ...
      spec:
        serviceAccountName: webapp
        initContainers:
          - name: webapp-certs
            env:
              - name: DOMAINS
                value: "app.webapp.com"
              - name: EMAIL
                value: "mail@webapp.com"
              - name: SECRET
                value: "webapp-tls"
              - name: SERVICE_FIELD
                value: "com.example.service"
              - name: SERVICE_NAME
                value: "webapp"
              - name: SERVICE_ACCOUNT
                value: "webapp"
            
            command:
              - /root/create-cron-job.sh
            image: ghcr.io/rosskouk/k8s-letsencrypt:v1


        containers:
          ...
```
