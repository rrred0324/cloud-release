---
target: kubernetes
description: "Kubernetes/Helm deployment — detect, deploy, rollback, and verify for container orchestration."
---

# Kubernetes Deployment Target

## Detection Signals

### Project layer
- `k8s/` directory with YAML manifests
- `kubernetes/` directory with YAML manifests
- `Chart.yaml` exists (Helm chart)
- `kustomization.yaml` exists (Kustomize)
- Manifest files containing `apiVersion:` and `kind:`

### Cloud environment
- `kubectl` configured and available
- Kubeconfig file exists (`~/.kube/config`)
- Cloud-managed K8s: EKS, GKE, AKS detected via cloud env vars
- `HELM_HOME` or `helm` command available

## Applicable Scenarios

- Microservices architectures
- High-availability deployments
- Auto-scaling requirements
- Multi-environment deployments (dev/staging/prod)

## Prerequisites

- `kubectl` installed and configured with correct context
- Container images built and pushed to registry
- Kubernetes manifests or Helm chart ready
- Appropriate RBAC permissions

## Deployment Steps Template

### Step 1: Build and push container image
```bash
docker build -t {registry}/{service_name}:{version} .
docker push {registry}/{service_name}:{version}
```

### Step 2: Update manifest image tag
```bash
# For raw manifests
sed -i "s|image:.*{service_name}.*|image: {registry}/{service_name}:{version}|" k8s/deployment.yaml

# For Kustomize
cd k8s/overlays/production
kustomize edit set image {service_name}={registry}/{service_name}:{version}
```

### Step 3: Apply manifests
```bash
# Raw manifests
kubectl apply -f k8s/ -n {namespace}

# Kustomize
kubectl apply -k k8s/overlays/production/ -n {namespace}

# Helm
helm upgrade {release_name} ./helm/ -n {namespace} --set image.tag={version}
```

### Step 4: Wait for rollout
```bash
kubectl rollout status deployment/{service_name} -n {namespace} --timeout=300s
```

### Step 5: Verify
```bash
kubectl get pods -n {namespace} -l app={service_name}
kubectl logs -n {namespace} -l app={service_name} --tail=20
```

## Configuration Generation

### Minimal Deployment manifest
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {service_name}
  namespace: {namespace}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {service_name}
  template:
    metadata:
      labels:
        app: {service_name}
    spec:
      containers:
      - name: {service_name}
        image: {registry}/{service_name}:{version}
        ports:
        - containerPort: 8000
        livenessProbe:
          httpGet:
            path: {health_check_url}
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: {health_check_url}
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: {service_name}
  namespace: {namespace}
spec:
  selector:
    app: {service_name}
  ports:
  - port: 80
    targetPort: 8000
  type: ClusterIP
```

## Rollback Plan

```bash
# Rollback to previous revision
kubectl rollout undo deployment/{service_name} -n {namespace}

# Rollback to specific revision
kubectl rollout undo deployment/{service_name} -n {namespace} --to-revision=2

# Helm rollback
helm rollback {release_name} {revision} -n {namespace}
```

## Post-Deployment Verification

- Pods running: `kubectl get pods -n {namespace}`
- Service endpoints: `kubectl get endpoints -n {namespace}`
- Health check: `kubectl port-forward -n {namespace} svc/{service_name} 8000:80` then `curl localhost:8000{health_check_url}`
- Events: `kubectl get events -n {namespace} --sort-by='.lastTimestamp'`
- Resource usage: `kubectl top pods -n {namespace}`

## Cost/Complexity

- **Cost**: Medium-High — cluster compute + load balancer + storage
- **Complexity**: High — K8s expertise required
- **Scalability**: High — horizontal pod autoscaling
- **Monitoring**: Prometheus + Grafana recommended

## Common Issues

1. **ImagePullBackOff**: Check image name/tag and registry credentials (`imagePullSecrets`)
2. **CrashLoopBackOff**: Check `kubectl logs <pod>` for application errors
3. **Pending pods**: Check `kubectl describe pod <pod>` for scheduling issues (resources, node selectors)
4. **ConfigMap/Secret not found**: Ensure all referenced configs exist in the namespace
5. **Rollout stuck**: Check `kubectl rollout status` and `kubectl get events`