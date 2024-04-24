#!/usr/bin/env bash

set -o errexit -o nounset -o errtrace -o pipefail -x

apk add helm

# Function to retry a command until it succeeds or reaches max attempts
# Arguments:
#   $1: max_attempts
#   $2: interval (seconds)
#   $3: description of the operation
#   ${@:4}: command to execute
retry_command() {
    local max_attempts=$1
    local interval=$2
    local description=$3
    local cmd="${@:4}"
    local attempt=1

    echo "Retrying: $description"
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt: $cmd"
        if eval $cmd; then
            echo "Success on attempt $attempt for: $description"
            return 0
        else
            echo "Failure on attempt $attempt for: $description"
            sleep $interval
        fi
        ((attempt++))
    done

    echo "Error: Failed after $max_attempts attempts for: $description"
    return 1
}

# Dependency: Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace ${NAMESPACE} --create-namespace \
    --set image.repository=cgr.dev/chainguard/cert-manager-controller \
    --set image.tag=latest \
    --set cainjector.image.repository=cgr.dev/chainguard/cert-manager-cainjector \
    --set cainjector.image.tag=latest \
    --set acmesolver.image.repository=cgr.dev/chainguard/cert-manager-acmesolver \
    --set acmesolver.image.tag=latest \
    --set webhook.image.repository=cgr.dev/chainguard/cert-manager-webhook \
    --set webhook.image.tag=latest \
    --set installCRDs=true

# Check readiness of cert-manager pods
retry_command 5 15 "cert-manager pod readiness" "kubectl wait --for=condition=ready pod --selector app.kubernetes.io/instance=cert-manager --namespace ${NAMESPACE} --timeout=1m"


# Dependency: minio deployment
# **NOTE**: This approach is a lot more involved, but I aligned with how the
# upstream maintainer said they setup for testing. See:
# - https://github.com/k8ssandra/k8ssandra-operator/issues/1185#issuecomment-1906230025
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: minio
  name: minio
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        command:
        - /bin/bash
        - -c
        args:
        - minio server /data --console-address :9090
        volumeMounts:
        - mountPath: /data
          name: localvolume
      volumes:
      - name: localvolume
        emptyDir:
          sizeLimit: 500Mi
EOF

# Dependency: minio service
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: minio-service
  namespace: ${NAMESPACE}
spec:
  selector:
    app: minio
  ports:
    - protocol: TCP
      name: api
      port: 9000
      targetPort: 9000
    - protocol: TCP
      name: admin-console
      port: 9090
      targetPort: 9090
EOF

# Dependency: Run minio
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: setup-minio
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: setup-minio-pod
          image: minio/mc
          command: ["bash", "-c"]
          args:
            - |
              mc alias set k8s-minio http://minio-service.${NAMESPACE}.svc.cluster.local:9000 minioadmin minioadmin
              mc mb k8s-minio/k8ssandra-medusa
              mc admin user add k8s-minio k8ssandra k8ssandra
              mc admin policy attach k8s-minio readwrite --user k8ssandra
EOF


# Dependency: Install k8ssandra-operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --set image.registry=cgr.dev \
  --set image.repository=chainguard/k8ssandra-operator \
  --set image.tag=latest

# Check readiness of k8sandra-operator
retry_command 5 15 "k8ssandra-operator pod readiness" "kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=k8ssandra-operator --namespace ${NAMESPACE} --timeout=1m"

# Create K8ssandraCluster
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
spec:
  cassandra:
    serverVersion: "4.0.1"
    datacenters:
      - metadata:
          name: ${NAME}
        size: 1
        storageConfig:
          cassandraDataVolumeClaimSpec:
            storageClassName: local-path
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 1Gi
        config:
          jvmOptions:
            heapSize: 512M
        stargate:
          size: 1
          heapSize: 256M
          affinity:
            podAntiAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
                - weight: 1
                  podAffinityTerm:
                    labelSelector:
                      matchLabels:
                        "app.kubernetes.io/name": "stargate"
                    topologyKey: "kubernetes.io/hostname"
  medusa:
    storageProperties:
      storageProvider: s3_compatible
      bucketName: k8ssandra-medusa
      prefix: test
      storageSecretRef:
        name: medusa-bucket-key
      host: minio-service.${NAMESPACE}.svc.cluster.local
      port: 9000
      secure: false
EOF

kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
 name: medusa-bucket-key
type: Opaque
stringData:
 # Note that this currently has to be set to credentials!
 credentials: |-
   [default]
   aws_access_key_id = k8ssandra
   aws_secret_access_key = k8ssandra
EOF

# Check readiness of the Cassandra Medusa pod
retry_command 5 15 "Cassandra Medusa pod readiness" "kubectl wait --for=condition=Ready pod -l app=${NAME}-cassandra-medusa-medusa-standalone -n ${NAMESPACE} --timeout=2m"

# Check readiness of the Cassandra stateful set
retry_command 20 30 "Cassandra stateful set readiness" "kubectl get statefulset ${NAME}-cassandra-medusa-default-sts -n ${NAMESPACE} --no-headers -o custom-columns=READY:.status.readyReplicas | grep -q '1'"

# Check Medusa gRPC server startup
sleep 5
kubectl logs -l app=${NAME}-cassandra-medusa-medusa-standalone --tail -1 -n ${NAMESPACE} | grep "Starting server. Listening on port 50051"

# Create Medusa Backup
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: medusa.k8ssandra.io/v1alpha1
kind: MedusaBackup
metadata:
  name: ${NAME}-backup
  namespace: ${NAMESPACE}
spec:
  backupType: full
  cassandraDatacenter: ${NAME}
EOF

# Verify creation of the MedusaBackup resource
retry_command 5 15 "MedusaBackup resource creation" "kubectl get medusabackup -n ${NAMESPACE} 2>&1 | grep -q '${NAME}-backup'"
