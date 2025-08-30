# Microservices Kubernetes Deployment Script for Windows
# This script deploys the complete microservices stack with Istio and ArgoCD

param(
    [Parameter(Position=0)]
    [ValidateSet("deploy", "status", "cleanup", "help")]
    [string]$Command = "deploy"
)

# Configuration
$NAMESPACE = "microservices-demo"
$ARGOCD_NAMESPACE = "argocd"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if kubectl is available
function Test-Kubectl {
    try {
        $null = Get-Command kubectl -ErrorAction Stop
        Write-Success "kubectl found"
    }
    catch {
        Write-Error "kubectl is not installed or not in PATH"
        exit 1
    }
}

# Function to check if namespace exists
function Test-Namespace {
    try {
        $null = kubectl get namespace $NAMESPACE 2>$null
        Write-Warning "Namespace $NAMESPACE already exists"
    }
    catch {
        Write-Status "Creating namespace $NAMESPACE"
        kubectl apply -f namespace.yaml
    }
}

# Function to apply manifests with error handling
function Apply-Manifest {
    param(
        [string]$File,
        [string]$Description
    )
    
    Write-Status "Applying $Description..."
    try {
        kubectl apply -f $File
        Write-Success "$Description applied successfully"
    }
    catch {
        Write-Error "Failed to apply $Description"
        exit 1
    }
}

# Function to wait for pods to be ready
function Wait-ForPods {
    param([string]$Deployment)
    
    $timeout = 300  # 5 minutes
    Write-Status "Waiting for $Deployment pods to be ready..."
    
    try {
        kubectl wait --for=condition=available --timeout=${timeout}s deployment/$Deployment -n $NAMESPACE
        Write-Success "$Deployment is ready"
    }
    catch {
        Write-Error "$Deployment failed to become ready within ${timeout}s"
        kubectl describe deployment $Deployment -n $NAMESPACE
        kubectl get pods -n $NAMESPACE -l app=$Deployment
        exit 1
    }
}

# Function to validate Istio installation
function Test-Istio {
    Write-Status "Checking Istio installation..."
    
    try {
        $null = kubectl get namespace istio-system 2>$null
        Write-Success "Istio namespace found"
    }
    catch {
        Write-Error "Istio namespace not found. Please install Istio first."
        exit 1
    }
    
    try {
        $null = kubectl get pods -n istio-system | Select-String "istio-ingressgateway"
        Write-Success "Istio Ingress Gateway found"
    }
    catch {
        Write-Error "Istio Ingress Gateway not found. Please install Istio with ingress gateway."
        exit 1
    }
}

# Function to validate ArgoCD installation
function Test-ArgoCD {
    Write-Status "Checking ArgoCD installation..."
    
    try {
        $null = kubectl get namespace $ARGOCD_NAMESPACE 2>$null
        Write-Success "ArgoCD namespace found"
    }
    catch {
        Write-Error "ArgoCD namespace not found. Please install ArgoCD first."
        exit 1
    }
    
    try {
        $null = kubectl get pods -n $ARGOCD_NAMESPACE | Select-String "argocd-server"
        Write-Success "ArgoCD server found"
    }
    catch {
        Write-Error "ArgoCD server not found. Please install ArgoCD first."
        exit 1
    }
}

# Main deployment function
function Deploy-Microservices {
    Write-Status "Starting microservices deployment..."
    
    # Check prerequisites
    Test-Kubectl
    Test-Istio
    Test-ArgoCD
    
    # Create namespace
    Test-Namespace
    
    # Apply configurations (Wave 1)
    Write-Status "Applying Wave 1: Configurations and Database"
    Apply-Manifest "configmap.yaml" "ConfigMap"
    Apply-Manifest "secret.yaml" "Secrets"
    Apply-Manifest "mysql-deployment.yml" "MySQL Database"
    
    # Wait for MySQL to be ready
    Wait-ForPods "mysql"
    
    # Apply services and deployments (Wave 2)
    Write-Status "Applying Wave 2: Services and Deployments"
    Apply-Manifest "service.yaml" "Services"
    Apply-Manifest "eurekha-server-deployment.yml" "Eureka Server"
    Apply-Manifest "api-gateway-deployment.yml" "API Gateway"
    Apply-Manifest "admin-service-deployment.yml" "Admin Service"
    Apply-Manifest "faculty-service-deployment.yml" "Faculty Service"
    Apply-Manifest "student-service-deployment.yml" "Student Service"
    
    # Wait for critical services
    Wait-ForPods "eureka-server"
    Wait-ForPods "api-gateway"
    
    # Apply Istio configurations (Wave 3)
    Write-Status "Applying Wave 3: Istio Service Mesh"
    Apply-Manifest "istio-gateway.yaml" "Istio Gateway"
    Apply-Manifest "istio-virtualservices.yaml" "Istio Virtual Services"
    Apply-Manifest "istio-destinationrules.yaml" "Istio Destination Rules"
    Apply-Manifest "istio-policy.yaml" "Istio Policies"
    Apply-Manifest "istio-service-mesh.yaml" "Istio Service Mesh Configuration"
    
    # Apply autoscaling (Wave 4)
    Write-Status "Applying Wave 4: Autoscaling"
    Apply-Manifest "hpa-config.yml" "Horizontal Pod Autoscalers"
    
    # Apply monitoring (Wave 5)
    Write-Status "Applying Wave 5: Monitoring"
    Apply-Manifest "monitoring-config.yaml" "Monitoring Configuration"
    
    # Apply ArgoCD configurations
    Write-Status "Applying ArgoCD Configuration"
    Apply-Manifest "argocd-project.yaml" "ArgoCD Project"
    Apply-Manifest "argocd-application.yaml" "ArgoCD Application"
    
    Write-Success "Deployment completed successfully!"
}

# Function to show deployment status
function Show-Status {
    Write-Status "Checking deployment status..."
    
    Write-Host "`nPod Status:" -ForegroundColor Blue
    kubectl get pods -n $NAMESPACE
    
    Write-Host "`nService Status:" -ForegroundColor Blue
    kubectl get services -n $NAMESPACE
    
    Write-Host "`nIstio Resources:" -ForegroundColor Blue
    kubectl get virtualservices,destinationrules,gateway -n $NAMESPACE
    
    Write-Host "`nHPA Status:" -ForegroundColor Blue
    kubectl get hpa -n $NAMESPACE
    
    Write-Host "`nArgoCD Application Status:" -ForegroundColor Blue
    kubectl get application microservices-app -n $ARGOCD_NAMESPACE
}

# Function to clean up deployment
function Remove-Deployment {
    Write-Status "Cleaning up deployment..."
    
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
    
    Write-Success "Cleanup completed"
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\deploy.ps1 [COMMAND]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  deploy    Deploy the complete microservices stack"
    Write-Host "  status    Show deployment status"
    Write-Host "  cleanup   Remove all deployed resources"
    Write-Host "  help      Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 deploy"
    Write-Host "  .\deploy.ps1 status"
    Write-Host "  .\deploy.ps1 cleanup"
}

# Main script logic
switch ($Command) {
    "deploy" {
        Deploy-Microservices
    }
    "status" {
        Show-Status
    }
    "cleanup" {
        Remove-Deployment
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}
