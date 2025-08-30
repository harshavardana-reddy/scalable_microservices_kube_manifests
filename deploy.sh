#!/bin/bash

# Microservices Kubernetes Deployment Script
# This script deploys the complete microservices stack with Istio and ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="microservices-demo"
ARGOCD_NAMESPACE="argocd"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_success "kubectl found"
}

# Function to check if namespace exists
check_namespace() {
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        print_status "Creating namespace $NAMESPACE"
        kubectl apply -f namespace.yaml
    fi
}

# Function to apply manifests with error handling
apply_manifest() {
    local file=$1
    local description=$2
    
    print_status "Applying $description..."
    if kubectl apply -f "$file"; then
        print_success "$description applied successfully"
    else
        print_error "Failed to apply $description"
        exit 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local deployment=$1
    local timeout=300  # 5 minutes
    
    print_status "Waiting for $deployment pods to be ready..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $NAMESPACE; then
        print_success "$deployment is ready"
    else
        print_error "$deployment failed to become ready within ${timeout}s"
        kubectl describe deployment $deployment -n $NAMESPACE
        kubectl get pods -n $NAMESPACE -l app=$deployment
        exit 1
    fi
}

# Function to check service endpoints
check_service_endpoints() {
    local service=$1
    
    print_status "Checking endpoints for $service..."
    if kubectl get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses}' | grep -q .; then
        print_success "$service has endpoints"
    else
        print_warning "$service has no endpoints yet"
    fi
}

# Function to validate Istio installation
check_istio() {
    print_status "Checking Istio installation..."
    if kubectl get namespace istio-system &> /dev/null; then
        print_success "Istio namespace found"
    else
        print_error "Istio namespace not found. Please install Istio first."
        exit 1
    fi
    
    if kubectl get pods -n istio-system | grep -q "istio-ingressgateway"; then
        print_success "Istio Ingress Gateway found"
    else
        print_error "Istio Ingress Gateway not found. Please install Istio with ingress gateway."
        exit 1
    fi
}

# Function to validate ArgoCD installation
check_argocd() {
    print_status "Checking ArgoCD installation..."
    if kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
        print_success "ArgoCD namespace found"
    else
        print_error "ArgoCD namespace not found. Please install ArgoCD first."
        exit 1
    fi
    
    if kubectl get pods -n $ARGOCD_NAMESPACE | grep -q "argocd-server"; then
        print_success "ArgoCD server found"
    else
        print_error "ArgoCD server not found. Please install ArgoCD first."
        exit 1
    fi
}

# Main deployment function
deploy_microservices() {
    print_status "Starting microservices deployment..."
    
    # Check prerequisites
    check_kubectl
    check_istio
    check_argocd
    
    # Create namespace
    check_namespace
    
    # Apply configurations (Wave 1)
    print_status "Applying Wave 1: Configurations and Database"
    apply_manifest "configmap.yaml" "ConfigMap"
    apply_manifest "secret.yaml" "Secrets"
    apply_manifest "mysql-deployment.yml" "MySQL Database"
    
    # Wait for MySQL to be ready
    wait_for_pods "mysql"
    
    # Apply services and deployments (Wave 2)
    print_status "Applying Wave 2: Services and Deployments"
    apply_manifest "service.yaml" "Services"
    apply_manifest "eurekha-server-deployment.yml" "Eureka Server"
    apply_manifest "api-gateway-deployment.yml" "API Gateway"
    apply_manifest "admin-service-deployment.yml" "Admin Service"
    apply_manifest "faculty-service-deployment.yml" "Faculty Service"
    apply_manifest "student-service-deployment.yml" "Student Service"
    
    # Wait for critical services
    wait_for_pods "eureka-server"
    wait_for_pods "api-gateway"
    
    # Apply Istio configurations (Wave 3)
    print_status "Applying Wave 3: Istio Service Mesh"
    apply_manifest "istio-gateway.yaml" "Istio Gateway"
    apply_manifest "istio-virtualservices.yaml" "Istio Virtual Services"
    apply_manifest "istio-destinationrules.yaml" "Istio Destination Rules"
    apply_manifest "istio-policy.yaml" "Istio Policies"
    apply_manifest "istio-service-mesh.yaml" "Istio Service Mesh Configuration"
    
    # Apply autoscaling (Wave 4)
    print_status "Applying Wave 4: Autoscaling"
    apply_manifest "hpa-config.yml" "Horizontal Pod Autoscalers"
    
    # Apply monitoring (Wave 5)
    print_status "Applying Wave 5: Monitoring"
    apply_manifest "monitoring-config.yaml" "Monitoring Configuration"
    
    # Apply ArgoCD configurations
    print_status "Applying ArgoCD Configuration"
    apply_manifest "argocd-project.yaml" "ArgoCD Project"
    apply_manifest "argocd-application.yaml" "ArgoCD Application"
    
    print_success "Deployment completed successfully!"
}

# Function to show deployment status
show_status() {
    print_status "Checking deployment status..."
    
    echo -e "\n${BLUE}Pod Status:${NC}"
    kubectl get pods -n $NAMESPACE
    
    echo -e "\n${BLUE}Service Status:${NC}"
    kubectl get services -n $NAMESPACE
    
    echo -e "\n${BLUE}Istio Resources:${NC}"
    kubectl get virtualservices,destinationrules,gateway -n $NAMESPACE
    
    echo -e "\n${BLUE}HPA Status:${NC}"
    kubectl get hpa -n $NAMESPACE
    
    echo -e "\n${BLUE}ArgoCD Application Status:${NC}"
    kubectl get application microservices-app -n $ARGOCD_NAMESPACE
}

# Function to clean up deployment
cleanup() {
    print_status "Cleaning up deployment..."
    
    # Delete ArgoCD application first
    kubectl delete -f argocd-application.yaml --ignore-not-found=true
    kubectl delete -f argocd-project.yaml --ignore-not-found=true
    
    # Delete all other resources
    kubectl delete -f monitoring-config.yaml --ignore-not-found=true
    kubectl delete -f hpa-config.yml --ignore-not-found=true
    kubectl delete -f istio-service-mesh.yaml --ignore-not-found=true
    kubectl delete -f istio-policy.yaml --ignore-not-found=true
    kubectl delete -f istio-destinationrules.yaml --ignore-not-found=true
    kubectl delete -f istio-virtualservices.yaml --ignore-not-found=true
    kubectl delete -f istio-gateway.yaml --ignore-not-found=true
    
    kubectl delete -f student-service-deployment.yml --ignore-not-found=true
    kubectl delete -f faculty-service-deployment.yml --ignore-not-found=true
    kubectl delete -f admin-service-deployment.yml --ignore-not-found=true
    kubectl delete -f api-gateway-deployment.yml --ignore-not-found=true
    kubectl delete -f eurekha-server-deployment.yml --ignore-not-found=true
    
    kubectl delete -f service.yaml --ignore-not-found=true
    kubectl delete -f mysql-deployment.yml --ignore-not-found=true
    kubectl delete -f secret.yaml --ignore-not-found=true
    kubectl delete -f configmap.yaml --ignore-not-found=true
    
    # Delete namespace
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    print_success "Cleanup completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy the complete microservices stack"
    echo "  status    Show deployment status"
    echo "  cleanup   Remove all deployed resources"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 status"
    echo "  $0 cleanup"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        deploy_microservices
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
