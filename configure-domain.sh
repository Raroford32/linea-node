#!/bin/bash

# Domain configuration script for Linea Node
# Configures nginx to work with a custom domain name

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [DOMAIN_NAME]"
    echo ""
    echo "Configure nginx to use a custom domain name"
    echo ""
    echo "Examples:"
    echo "  $0 my-linea-node.com"
    echo "  $0 rpc.mydomain.org"
    echo ""
    echo "To revert to IP-only configuration:"
    echo "  $0 --reset"
}

configure_domain() {
    local domain="$1"
    
    print_status "Configuring nginx for domain: $domain"
    
    # Backup current configuration
    if [ ! -f "nginx.conf.backup" ]; then
        cp nginx.conf nginx.conf.backup
        print_status "Created backup: nginx.conf.backup"
    fi
    
    # Update nginx configuration with domain
    sed "s/server_name _;/server_name $domain _;/g" nginx.conf.template > nginx.conf
    
    print_status "Updated nginx.conf with domain: $domain"
    
    # Update .env file
    if [ -f ".env" ]; then
        if grep -q "DOMAIN_NAME=" .env; then
            sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$domain/" .env
        else
            echo "DOMAIN_NAME=$domain" >> .env
        fi
    else
        echo "DOMAIN_NAME=$domain" > .env
    fi
    
    print_status "Updated .env file"
    
    # Restart nginx if it's running
    if sudo docker ps | grep -q "linea-nginx-lb"; then
        print_status "Restarting nginx container..."
        sudo docker-compose -f docker-compose-high-performance.yaml restart nginx-lb
        print_status "Nginx restarted successfully"
    else
        print_warning "Nginx container not running. Start with: sudo docker-compose up -d"
    fi
    
    echo ""
    print_status "Domain configuration complete!"
    echo "Your node is now configured for domain: $domain"
    echo ""
    echo "Available endpoints:"
    echo "• JSON-RPC: http://$domain/"
    echo "• WebSocket: ws://$domain:8080/"
    echo "• Health Check: http://$domain/health"
    echo ""
    print_warning "Make sure your domain DNS points to this server's IP address:"
    PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me || echo "unknown")
    echo "Server IP: $PUBLIC_IP"
}

reset_configuration() {
    print_status "Resetting to IP-only configuration..."
    
    if [ -f "nginx.conf.backup" ]; then
        cp nginx.conf.backup nginx.conf
        print_status "Restored nginx.conf from backup"
    else
        print_warning "No backup found, using default configuration"
        git checkout nginx.conf 2>/dev/null || true
    fi
    
    # Update .env file
    if [ -f ".env" ]; then
        sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=/" .env
        print_status "Cleared domain from .env file"
    fi
    
    # Restart nginx if it's running
    if sudo docker ps | grep -q "linea-nginx-lb"; then
        print_status "Restarting nginx container..."
        sudo docker-compose -f docker-compose-high-performance.yaml restart nginx-lb
        print_status "Nginx restarted successfully"
    fi
    
    print_status "Reset complete! Node is now configured for IP-only access."
}

validate_domain() {
    local domain="$1"
    
    # Basic domain validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]] && [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\..*$ ]]; then
        print_error "Invalid domain format: $domain"
        echo "Domain should be in format: example.com or subdomain.example.com"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    # Check if we're in the correct directory
    if [ ! -f "docker-compose-high-performance.yaml" ]; then
        print_error "This script must be run from the linea-node directory"
        echo "cd ~/linea-node && ./configure-domain.sh [domain]"
        exit 1
    fi
    
    case "$1" in
        "")
            usage
            exit 0
            ;;
        "--reset"|"-r")
            reset_configuration
            ;;
        "--help"|"-h")
            usage
            exit 0
            ;;
        *)
            if validate_domain "$1"; then
                configure_domain "$1"
            else
                exit 1
            fi
            ;;
    esac
}

main "$@"