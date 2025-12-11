#!/bin/bash
# Automated deployment script for GPU stress test cluster
# Usage: ./deploy.sh [deploy|destroy|status|collect-metrics]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
LOGS_DIR="$SCRIPT_DIR/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=0
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        missing=1
    else
        log_success "Terraform found: $(terraform version -json | jq -r .terraform_version)"
    fi
    
    if ! command -v ansible &> /dev/null; then
        log_warning "Ansible is not installed (optional but recommended)"
    else
        log_success "Ansible found: $(ansible --version | head -n1)"
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        missing=1
    else
        log_success "Python 3 found: $(python3 --version)"
    fi
    
    if [ ! -f "$HOME/.ssh/user-key.pub" ]; then
        log_error "SSH public key not found at $HOME/.ssh/user-key.pub"
        missing=1
    else
        log_success "SSH key found"
    fi
    
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found. Copy terraform.tfvars.example and configure it."
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Prerequisites check failed. Please install missing components."
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

deploy_infrastructure() {
    log_info "Starting infrastructure deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform..."
        terraform init
    fi
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Show plan
    log_info "Generating deployment plan..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    echo ""
    read -p "Do you want to proceed with deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_warning "Deployment cancelled"
        rm -f tfplan
        exit 0
    fi
    
    # Apply
    log_info "Applying Terraform configuration..."
    terraform apply tfplan
    rm -f tfplan
    
    log_success "Infrastructure deployed successfully!"
    
    # Generate inventory
    generate_inventory
    
    # Show summary
    show_cluster_summary
}

destroy_infrastructure() {
    log_warning "This will destroy all resources!"
    cd "$TERRAFORM_DIR"
    
    terraform show &> /dev/null || {
        log_error "No infrastructure found to destroy"
        exit 1
    }
    
    echo ""
    read -p "Are you sure you want to destroy everything? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Destroy cancelled"
        exit 0
    fi
    
    log_info "Destroying infrastructure..."
    terraform destroy -auto-approve
    
    log_success "Infrastructure destroyed successfully!"
}

generate_inventory() {
    log_info "Generating Ansible inventory..."
    
    cd "$TERRAFORM_DIR"
    terraform output -json > inventory.json
    
    if [ -f "generate_inventory.py" ]; then
        python3 generate_inventory.py
        log_success "Inventory generated at $ANSIBLE_DIR/inventory.ini"
    else
        log_error "generate_inventory.py not found"
        exit 1
    fi
}

show_cluster_summary() {
    log_info "Cluster Summary:"
    
    cd "$TERRAFORM_DIR"
    
    echo ""
    echo "=========================================="
    terraform output cluster_summary | grep -v "^{" | grep -v "^}" | sed 's/"//g'
    echo "=========================================="
    echo ""
    
    if [ -f "$ANSIBLE_DIR/inventory.ini" ]; then
        log_info "VM Groups and IPs:"
        echo ""
        cat "$ANSIBLE_DIR/inventory.ini" | grep -E "^\[|ansible_host" | head -n 50
    fi
    
    echo ""
    log_info "Next steps:"
    echo "  1. Verify connectivity: ansible all -i $ANSIBLE_DIR/inventory.ini -m ping"
    echo "  2. Start GPU monitoring: ansible gpu_vms -i $ANSIBLE_DIR/inventory.ini -b -m service -a 'name=gpu-monitor state=started'"
    echo "  3. Start stress tests: ansible stress_group1 -i $ANSIBLE_DIR/inventory.ini -b -m service -a 'name=stress-test state=started'"
}

show_status() {
    log_info "Checking cluster status..."
    
    cd "$TERRAFORM_DIR"
    
    if [ ! -d ".terraform" ]; then
        log_error "Terraform not initialized. Run './deploy.sh deploy' first."
        exit 1
    fi
    
    # Show Terraform state
    log_info "Terraform Resources:"
    terraform state list 2>/dev/null | wc -l | xargs echo "  Total resources:"
    
    echo ""
    show_cluster_summary
    
    # Check VM connectivity if Ansible is available
    if command -v ansible &> /dev/null && [ -f "$ANSIBLE_DIR/inventory.ini" ]; then
        echo ""
        log_info "Testing VM connectivity..."
        ansible all -i "$ANSIBLE_DIR/inventory.ini" -m ping -o 2>/dev/null || log_warning "Some VMs are not reachable"
    fi
}

collect_metrics() {
    log_info "Collecting metrics from all VMs..."
    
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible is required for metric collection"
        exit 1
    fi
    
    if [ ! -f "$ANSIBLE_DIR/inventory.ini" ]; then
        log_error "Inventory not found. Run './deploy.sh deploy' first."
        exit 1
    fi
    
    # Create logs directory
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    COLLECTION_DIR="$LOGS_DIR/metrics-$TIMESTAMP"
    mkdir -p "$COLLECTION_DIR"
    
    log_info "Saving metrics to: $COLLECTION_DIR"
    
    # Collect GPU metrics
    if ansible gpu_vms -i "$ANSIBLE_DIR/inventory.ini" --list-hosts &> /dev/null; then
        log_info "Collecting GPU metrics..."
        ansible gpu_vms -i "$ANSIBLE_DIR/inventory.ini" -m shell \
            -a "/opt/gpu-monitor/gpu-stats.sh" > "$COLLECTION_DIR/gpu-metrics.txt" 2>&1 || true
    fi
    
    # Collect stress VM metrics
    if ansible stress_vms -i "$ANSIBLE_DIR/inventory.ini" --list-hosts &> /dev/null; then
        log_info "Collecting stress test metrics..."
        ansible stress_vms -i "$ANSIBLE_DIR/inventory.ini" -m shell \
            -a "/opt/stress-test/monitor.sh" > "$COLLECTION_DIR/stress-metrics.txt" 2>&1 || true
    fi
    
    # Collect system load
    log_info "Collecting system load..."
    ansible all_cluster -i "$ANSIBLE_DIR/inventory.ini" -m shell \
        -a "uptime" > "$COLLECTION_DIR/system-load.txt" 2>&1 || true
    
    # Collect service status
    log_info "Collecting service status..."
    ansible stress_vms -i "$ANSIBLE_DIR/inventory.ini" -b -m shell \
        -a "systemctl is-active stress-test" > "$COLLECTION_DIR/stress-status.txt" 2>&1 || true
    
    ansible gpu_vms -i "$ANSIBLE_DIR/inventory.ini" -b -m shell \
        -a "systemctl is-active gpu-monitor" > "$COLLECTION_DIR/gpu-monitor-status.txt" 2>&1 || true
    
    log_success "Metrics collected successfully!"
    log_info "Results saved in: $COLLECTION_DIR"
    
    echo ""
    log_info "Summary:"
    ls -lh "$COLLECTION_DIR"
}

start_stress_tests() {
    log_info "Starting stress tests on all groups..."
    
    if [ ! -f "$ANSIBLE_DIR/inventory.ini" ]; then
        log_error "Inventory not found. Deploy infrastructure first."
        exit 1
    fi
    
    local group=${1:-"all"}
    
    case $group in
        1|group1)
            log_info "Starting stress test on Group 1 (light load)..."
            ansible stress_group1 -i "$ANSIBLE_DIR/inventory.ini" -b -m service \
                -a "name=stress-test state=started"
            ;;
        2|group2)
            log_info "Starting stress test on Group 2 (medium load)..."
            ansible stress_group2 -i "$ANSIBLE_DIR/inventory.ini" -b -m service \
                -a "name=stress-test state=started"
            ;;
        3|group3)
            log_info "Starting stress test on Group 3 (heavy load)..."
            ansible stress_group3 -i "$ANSIBLE_DIR/inventory.ini" -b -m service \
                -a "name=stress-test state=started"
            ;;
        all)
            log_info "Starting stress tests on all groups..."
            ansible stress_vms -i "$ANSIBLE_DIR/inventory.ini" -b -m service \
                -a "name=stress-test state=started"
            ;;
        *)
            log_error "Invalid group: $group. Use 1, 2, 3, or all"
            exit 1
            ;;
    esac
    
    log_success "Stress tests started!"
}

stop_stress_tests() {
    log_info "Stopping all stress tests..."
    
    if [ ! -f "$ANSIBLE_DIR/inventory.ini" ]; then
        log_error "Inventory not found."
        exit 1
    fi
    
    ansible stress_vms -i "$ANSIBLE_DIR/inventory.ini" -b -m service \
        -a "name=stress-test state=stopped"
    
    log_success "All stress tests stopped!"
}

show_usage() {
    cat << EOF
GPU Stress Test Cluster - Deployment Script

Usage: $0 <command> [options]

Commands:
    deploy              Deploy the infrastructure
    destroy             Destroy all resources
    status              Show cluster status
    collect-metrics     Collect metrics from all VMs
    start-stress [GROUP] Start stress tests (GROUP: 1, 2, 3, or all)
    stop-stress         Stop all stress tests
    inventory           Regenerate Ansible inventory
    check               Check prerequisites
    help                Show this help message

Examples:
    $0 deploy                    # Deploy infrastructure
    $0 start-stress 1            # Start stress on group 1 only
    $0 start-stress all          # Start stress on all groups
    $0 collect-metrics           # Collect current metrics
    $0 destroy                   # Destroy everything

For more information, see README.md
EOF
}

# Main script logic
case "${1:-help}" in
    deploy)
        check_prerequisites
        deploy_infrastructure
        ;;
    destroy)
        destroy_infrastructure
        ;;
    status)
        show_status
        ;;
    collect-metrics|metrics)
        collect_metrics
        ;;
    start-stress)
        start_stress_tests "${2:-all}"
        ;;
    stop-stress)
        stop_stress_tests
        ;;
    inventory)
        generate_inventory
        ;;
    check)
        check_prerequisites
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
