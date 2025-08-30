# Microservices Kubernetes Manifests

This directory contains comprehensive Kubernetes manifests for deploying a microservices architecture with Istio service mesh and ArgoCD GitOps.

## Architecture Overview

The microservices architecture consists of:

- **API Gateway**: Entry point for all external requests
- **Admin Service**: Admin management functionality
- **Faculty Service**: Faculty-related operations
- **Student Service**: Student-related operations
- **Eureka Server**: Service discovery and registration
- **MySQL Database**: Persistent data storage

## Prerequisites

1. **Kubernetes Cluster**: v1.20+
2. **Istio**: v1.15+ installed with service mesh
3. **ArgoCD**: v2.5+ installed for GitOps
4. **Prometheus Operator**: For monitoring (optional)
5. **Docker Images**: All microservices must be built and pushed to registry

## Directory Structure

```
kubernates/
├── namespace.yaml                 # Namespace configuration
├── configmap.yaml                 # Application configuration
├── secret.yaml                    # Sensitive data (passwords, keys)
├── service.yaml                   # All Kubernetes services
├── mysql-deployment.yml          # MySQL database deployment
├── eurekha-server-deployment.yml # Eureka server deployment
├── api-gateway-deployment.yml    # API Gateway deployment
├── admin-service-deployment.yml  # Admin service deployment
├── faculty-service-deployment.yml # Faculty service deployment
├── student-service-deployment.yml # Student service deployment
├── hpa-config.yml                # Horizontal Pod Autoscalers
├── istio-gateway.yaml            # Istio Gateway configuration
├── istio-virtualservices.yaml    # Istio VirtualServices
├── istio-destinationrules.yaml   # Istio DestinationRules
├── istio-policy.yaml             # Istio policies and filters
├── istio-service-mesh.yaml       # Service mesh configuration
├── monitoring-config.yaml        # Prometheus monitoring
├── argocd-project.yaml           # ArgoCD project configuration
├── argocd-application.yaml       # ArgoCD application
└── README.md                     # This file
```

## Deployment Order

The manifests use ArgoCD sync waves to ensure proper deployment order:

1. **Wave 0**: Namespace creation
2. **Wave 1**: ConfigMaps, Secrets, MySQL, PVCs
3. **Wave 2**: Deployments and Services
4. **Wave 3**: Istio configurations (Gateway, VirtualServices, DestinationRules)
5. **Wave 4**: Horizontal Pod Autoscalers
6. **Wave 5**: Monitoring configurations

## Configuration

### Environment Variables

All services use a centralized ConfigMap (`microservices-config`) for configuration:

- Database connection settings
- Eureka server URL
- Service ports
- Logging levels

### Secrets

Sensitive data is stored in Kubernetes secrets:

- Database passwords
- API keys (if needed)

## Istio Service Mesh

### Gateway

- External access through Istio Ingress Gateway
- HTTP and HTTPS support
- TLS termination

### Virtual Services

- Route external traffic to appropriate services
- Path-based routing (`/admin/*`, `/faculty/*`, `/student/*`)
- Load balancing and failover

### Destination Rules

- Traffic policies with mTLS
- Connection pooling
- Circuit breaker patterns

### Security

- Authorization policies
- mTLS between services
- Rate limiting

## Monitoring and Observability

### Prometheus Integration

- ServiceMonitors for each microservice
- Custom metrics collection
- Health check endpoints

### Grafana Dashboards

- Pre-configured dashboards for microservices
- Performance metrics
- Error rate monitoring

## ArgoCD GitOps

### Project Configuration

- RBAC for different user roles
- Resource whitelisting
- Repository access control

### Application Configuration

- Automated sync with self-healing
- Prune policies
- Retry mechanisms
- Revision history

## Deployment Commands

### Manual Deployment

```bash
# Apply namespace first
kubectl apply -f namespace.yaml

# Apply configurations
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# Apply database
kubectl apply -f mysql-deployment.yml

# Apply services
kubectl apply -f service.yaml

# Apply deployments
kubectl apply -f eurekha-server-deployment.yml
kubectl apply -f api-gateway-deployment.yml
kubectl apply -f admin-service-deployment.yml
kubectl apply -f faculty-service-deployment.yml
kubectl apply -f student-service-deployment.yml

# Apply Istio configurations
kubectl apply -f istio-gateway.yaml
kubectl apply -f istio-virtualservices.yaml
kubectl apply -f istio-destinationrules.yaml
kubectl apply -f istio-policy.yaml
kubectl apply -f istio-service-mesh.yaml

# Apply autoscaling
kubectl apply -f hpa-config.yml

# Apply monitoring
kubectl apply -f monitoring-config.yaml
```

### ArgoCD Deployment

```bash
# Apply ArgoCD project
kubectl apply -f argocd-project.yaml

# Apply ArgoCD application
kubectl apply -f argocd-application.yaml
```

## Access Points

### External Access

- **API Gateway**: LoadBalancer service on port 4000
- **Eureka Dashboard**: Through API Gateway at `/eureka`

### Internal Services

- **Admin Service**: Port 4001
- **Faculty Service**: Port 4002
- **Student Service**: Port 4003
- **Eureka Server**: Port 8761
- **MySQL**: Port 3306

## Health Checks

All services include:

- **Readiness Probe**: `/actuator/health` endpoints
- **Liveness Probe**: Health check with proper timeouts
- **Startup Probe**: Initial delay for application startup

## Scaling

### Horizontal Pod Autoscalers

- CPU threshold: 70%
- Memory threshold: 80%
- Min replicas: 2
- Max replicas: 10
- Scale up/down behavior configured

### Manual Scaling

```bash
kubectl scale deployment admin-service --replicas=3 -n microservices-demo
```

## Troubleshooting

### Common Issues

1. **Service Discovery**: Ensure Eureka server is running and accessible
2. **Database Connection**: Check MySQL service and credentials
3. **Istio Sidecar**: Verify sidecar injection is enabled
4. **ArgoCD Sync**: Check application status in ArgoCD UI

### Debug Commands

```bash
# Check pod status
kubectl get pods -n microservices-demo

# Check service endpoints
kubectl get endpoints -n microservices-demo

# Check Istio resources
kubectl get virtualservices,destinationrules,gateway -n microservices-demo

# Check ArgoCD application status
kubectl get application microservices-app -n argocd
```

## Security Considerations

1. **Network Policies**: Implement network policies for service-to-service communication
2. **RBAC**: Use proper service accounts and role bindings
3. **Secrets Management**: Use external secret management in production
4. **TLS**: Enable mTLS for all service communication
5. **Authorization**: Implement proper authorization policies

## Performance Optimization

1. **Resource Limits**: Configure appropriate CPU and memory limits
2. **Connection Pooling**: Use Istio connection pooling
3. **Caching**: Implement application-level caching
4. **CDN**: Use CDN for static assets
5. **Database Optimization**: Optimize database queries and indexes

## Backup and Recovery

1. **Database Backups**: Regular MySQL backups
2. **Configuration Backups**: Version control for all configurations
3. **Disaster Recovery**: Multi-region deployment strategy
4. **Rollback Procedures**: Use ArgoCD rollback features

## Contributing

1. Follow the existing manifest structure
2. Add proper annotations for ArgoCD sync waves
3. Include health checks and resource limits
4. Document any new configurations
5. Test deployments in staging environment first
