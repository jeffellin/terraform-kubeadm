#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 <environment> [action] [options]

ENVIRONMENTS:
  proxmox    Deploy to Proxmox
  aws        Deploy to AWS

ACTIONS:
  init       Initialize Terraform (default)
  plan       Run terraform plan
  apply      Run terraform apply
  destroy    Run terraform destroy
  output     Show terraform outputs
  clean      Clean up terraform state files

OPTIONS:
  -var-file=FILE    Specify custom terraform.tfvars file
  -auto-approve     Auto-approve terraform apply/destroy
  -help            Show this help message

EXAMPLES:
  $0 proxmox                    # Initialize and plan Proxmox deployment
  $0 aws apply                  # Apply AWS deployment
  $0 proxmox destroy -auto-approve  # Destroy Proxmox with auto-approve
  $0 aws plan -var-file=prod.tfvars # Plan AWS with custom vars file

ENVIRONMENT VARIABLES:
  TF_VAR_*         Terraform variables (e.g., TF_VAR_cluster_name=my-cluster)
  TERRAFORM_DIR    Override environment directory (advanced)
EOF
}

# Parse arguments
ENVIRONMENT=""
ACTION="init"
TF_ARGS=""
VAR_FILE=""
AUTO_APPROVE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        proxmox|aws)
            ENVIRONMENT="$1"
            shift
            ;;
        init|plan|apply|destroy|output|clean)
            ACTION="$1"
            shift
            ;;
        -var-file=*)
            VAR_FILE="${1#*=}"
            TF_ARGS="$TF_ARGS -var-file=$VAR_FILE"
            shift
            ;;
        -auto-approve)
            AUTO_APPROVE="-auto-approve"
            shift
            ;;
        -help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            TF_ARGS="$TF_ARGS $1"
            shift
            ;;
    esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment is required!"
    echo
    show_usage
    exit 1
fi

if [[ "$ENVIRONMENT" != "proxmox" && "$ENVIRONMENT" != "aws" ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Must be 'proxmox' or 'aws'"
    exit 1
fi

# Set environment directory
ENV_DIR="${TERRAFORM_DIR:-$ENVIRONMENT}"

# Validate environment directory exists
if [[ ! -d "$ENV_DIR" ]]; then
    print_error "Environment directory '$ENV_DIR' does not exist!"
    exit 1
fi

# Change to environment directory
print_info "Switching to $ENVIRONMENT environment: $ENV_DIR"
cd "$ENV_DIR"

# Validate terraform files exist
if [[ ! -f "main.tf" ]]; then
    print_error "main.tf not found in $ENV_DIR directory!"
    exit 1
fi

# Set default var file if not specified
if [[ -z "$VAR_FILE" ]] && [[ -f "terraform.tfvars" ]]; then
    print_info "Using terraform.tfvars file"
elif [[ -z "$VAR_FILE" ]] && [[ -f "terraform.tfvars.example" ]]; then
    print_warning "terraform.tfvars not found, but terraform.tfvars.example exists"
    print_warning "Copy terraform.tfvars.example to terraform.tfvars and customize it"
fi

# Execute action
case $ACTION in
    init)
        print_info "Initializing Terraform for $ENVIRONMENT..."
        terraform init
        print_success "Terraform initialized successfully"

        print_info "Running terraform plan..."
        terraform plan $TF_ARGS
        ;;

    plan)
        print_info "Running terraform plan for $ENVIRONMENT..."
        terraform plan $TF_ARGS
        ;;

    apply)
        print_info "Applying Terraform configuration for $ENVIRONMENT..."
        terraform apply $AUTO_APPROVE $TF_ARGS

        if [[ $? -eq 0 ]]; then
            print_success "Deployment completed successfully!"
            echo
            print_info "Getting outputs..."
            terraform output
        fi
        ;;

    destroy)
        print_warning "This will destroy all resources for $ENVIRONMENT!"
        if [[ -z "$AUTO_APPROVE" ]]; then
            read -p "Are you sure? (yes/no): " confirm
            if [[ "$confirm" != "yes" ]]; then
                print_info "Destroy cancelled"
                exit 0
            fi
        fi

        print_info "Destroying Terraform resources for $ENVIRONMENT..."
        terraform destroy $AUTO_APPROVE $TF_ARGS
        ;;

    output)
        print_info "Showing outputs for $ENVIRONMENT..."
        terraform output
        ;;

    clean)
        print_warning "This will remove Terraform state files!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            rm -rf .terraform terraform.tfstate* .terraform.lock.hcl
            print_success "Terraform state cleaned"
        else
            print_info "Clean cancelled"
        fi
        ;;

    *)
        print_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac