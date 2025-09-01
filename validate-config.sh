#!/bin/bash

# Configuration validation script
# Tests all configuration files for syntax errors

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

validate_docker_compose() {
    local file=$1
    echo "Validating $file..."
    
    if [ ! -f "$file" ]; then
        print_error "$file does not exist"
        return 1
    fi
    
    # Check if docker-compose can parse the file
    if docker-compose -f "$file" config > /dev/null 2>&1; then
        print_status "$file syntax is valid"
    else
        print_error "$file has syntax errors"
        docker-compose -f "$file" config
        return 1
    fi
}

validate_nginx_config() {
    echo "Validating nginx.conf..."
    
    if [ ! -f "nginx.conf" ]; then
        print_error "nginx.conf does not exist"
        return 1
    fi
    
    # Basic syntax check - nginx -t won't work without the container network
    # So we'll do structural validation instead
    if grep -q "upstream.*{" nginx.conf && grep -q "server.*{" nginx.conf && grep -q "location.*{" nginx.conf; then
        print_status "nginx.conf basic structure looks valid"
        
        # Check for required upstream blocks
        if grep -q "upstream besu_rpc_backend" nginx.conf && grep -q "upstream besu_ws_backend" nginx.conf; then
            print_status "nginx.conf upstream configurations are present"
        else
            print_error "nginx.conf missing required upstream configurations"
            return 1
        fi
        
        # Check for load balancing configuration
        if grep -q "least_conn" nginx.conf; then
            print_status "nginx.conf load balancing is configured"
        else
            print_warning "nginx.conf load balancing method not explicitly set"
        fi
        
    else
        print_error "nginx.conf appears to have structural issues"
        return 1
    fi
}

validate_prometheus_config() {
    echo "Validating prometheus.yml..."
    
    if [ ! -f "prometheus.yml" ]; then
        print_error "prometheus.yml does not exist"
        return 1
    fi
    
    # Basic YAML syntax check
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('prometheus.yml'))" 2>/dev/null; then
            print_status "prometheus.yml YAML syntax is valid"
        else
            print_error "prometheus.yml has YAML syntax errors"
            return 1
        fi
    else
        print_warning "Python3 not available, skipping YAML validation"
    fi
}

check_script_syntax() {
    local script=$1
    echo "Checking $script syntax..."
    
    if [ ! -f "$script" ]; then
        print_error "$script does not exist"
        return 1
    fi
    
    if bash -n "$script"; then
        print_status "$script syntax is valid"
    else
        print_error "$script has syntax errors"
        return 1
    fi
}

perform_basic_tests() {
    echo "Performing basic functionality tests..."
    
    # Test if PUBLIC_IP replacement works
    if grep -q "\${PUBLIC_IP" docker-compose-high-performance.yaml; then
        print_status "PUBLIC_IP variable substitution configured"
    else
        print_warning "PUBLIC_IP variable substitution may not be configured"
    fi
    
    # Check if all required ports are defined
    local required_ports=("80" "8080" "30303" "9091")
    for port in "${required_ports[@]}"; do
        if grep -q "${port}:" docker-compose-high-performance.yaml; then
            print_status "Port $port is configured"
        else
            print_error "Port $port is not configured"
        fi
    done
    
    # Check if volumes are defined
    if grep -q "volumes:" docker-compose-high-performance.yaml; then
        print_status "Docker volumes are configured"
    else
        print_error "Docker volumes are not configured"
    fi
}

main() {
    echo "=================================================================="
    echo "           Configuration Validation Script"
    echo "=================================================================="
    
    local errors=0
    
    # Validate Docker Compose files
    validate_docker_compose "docker-compose-high-performance.yaml" || ((errors++))
    validate_docker_compose "docker-compose-dev.yaml" || ((errors++))
    
    echo ""
    
    # Validate Nginx configuration
    validate_nginx_config || ((errors++))
    
    echo ""
    
    # Validate Prometheus configuration  
    validate_prometheus_config || ((errors++))
    
    echo ""
    
    # Check script syntax
    check_script_syntax "install-high-performance.sh" || ((errors++))
    check_script_syntax "benchmark.sh" || ((errors++))
    
    echo ""
    
    # Perform basic tests
    perform_basic_tests
    
    echo ""
    echo "=================================================================="
    if [ $errors -eq 0 ]; then
        print_status "All configurations are valid!"
        echo "You can safely deploy these configurations."
    else
        print_error "Found $errors error(s) in configurations"
        echo "Please fix the errors before deploying."
        exit 1
    fi
    echo "=================================================================="
}

main "$@"