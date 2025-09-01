#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_SETUP="high-performance"
INSTALL_DIR="$HOME/linea-node"

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "    Linea Besu High-Performance Node Installation Script"
    echo "=================================================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    print_status "Checking system requirements..."
    
    # Check available memory (minimum 16GB recommended for high-performance setup)
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM / 1024 / 1024))
    
    if [ $TOTAL_MEM_GB -lt 16 ]; then
        print_warning "System has ${TOTAL_MEM_GB}GB RAM. High-performance setup requires at least 16GB for optimal performance."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "System has ${TOTAL_MEM_GB}GB RAM - sufficient for high-performance setup"
    fi
    
    # Check available disk space (minimum 500GB recommended)
    AVAILABLE_SPACE=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $AVAILABLE_SPACE -lt 500 ]; then
        print_warning "Available disk space: ${AVAILABLE_SPACE}GB. Recommended: 500GB+ for blockchain data"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "Available disk space: ${AVAILABLE_SPACE}GB - sufficient"
    fi
}

select_setup_type() {
    echo -e "${BLUE}Available setup types:${NC}"
    echo "1. High-Performance (default) - Multiple nodes + load balancer + caching + monitoring"
    echo "2. Basic - Single node (original setup)"
    echo "3. Development - Single node with debugging enabled"
    echo ""
    read -p "Select setup type [1-3] (default: 1): " SETUP_CHOICE
    
    case $SETUP_CHOICE in
        2)
            SETUP_TYPE="basic"
            COMPOSE_FILE="docker-compose.yaml"
            ;;
        3)
            SETUP_TYPE="development"
            COMPOSE_FILE="docker-compose-dev.yaml"
            ;;
        *)
            SETUP_TYPE="high-performance"
            COMPOSE_FILE="docker-compose-high-performance.yaml"
            ;;
    esac
    
    print_status "Selected setup type: $SETUP_TYPE"
}

configure_domain() {
    if [ "$SETUP_TYPE" == "high-performance" ]; then
        echo ""
        echo -e "${BLUE}Domain Configuration (Optional):${NC}"
        echo "You can configure a custom domain name for your Linea node."
        echo "This is optional - you can always configure it later using ./configure-domain.sh"
        echo ""
        read -p "Do you have a domain name you'd like to use? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            while true; do
                read -p "Enter your domain name (e.g., my-linea-node.com): " DOMAIN_INPUT
                
                if [ -z "$DOMAIN_INPUT" ]; then
                    print_warning "Domain name cannot be empty. Skipping domain configuration."
                    break
                fi
                
                # Basic domain validation
                if [[ "$DOMAIN_INPUT" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
                    DOMAIN_NAME="$DOMAIN_INPUT"
                    print_status "Domain configured: $DOMAIN_NAME"
                    echo "DOMAIN_NAME=$DOMAIN_NAME" >> .env
                    
                    # Configure nginx template
                    if [ -f "nginx.conf.template" ]; then
                        sed "s/server_name _;/server_name $DOMAIN_NAME _;/g" nginx.conf.template > nginx.conf
                        print_status "Nginx configured for domain: $DOMAIN_NAME"
                    fi
                    break
                else
                    print_error "Invalid domain format. Please enter a valid domain name."
                fi
            done
        else
            print_status "Skipping domain configuration. You can configure it later with ./configure-domain.sh"
        fi
    fi
}

install_dependencies() {
    print_status "Installing required packages..."
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package list
    sudo apt-get update -qq > /dev/null
    
    # Install basic dependencies
    sudo apt-get install -y -qq curl wget jq htop iotop > /dev/null
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        print_status "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh > /dev/null
        rm get-docker.sh
    else
        print_status "Docker already installed"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        print_status "Installing Docker Compose..."
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        print_status "Docker Compose already installed"
    fi
    
    # Configure Docker permissions
    print_status "Configuring Docker permissions..."
    sudo usermod -aG docker $USER
}

setup_node_directory() {
    print_status "Setting up node directory..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Get public IP
    print_status "Detecting public IP address..."
    PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me || curl -s --max-time 10 icanhazip.com || echo "127.0.0.1")
    print_status "Detected public IP: $PUBLIC_IP"
    
    # Create .env file
    cat > .env << EOF
PUBLIC_IP=$PUBLIC_IP
SETUP_TYPE=$SETUP_TYPE
INSTALL_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
}

download_configurations() {
    print_status "Downloading configuration files..."
    
    # Base URL for configurations
    BASE_URL="https://raw.githubusercontent.com/Raroford32/linea-node/main"
    
    if [ "$SETUP_TYPE" == "basic" ]; then
        # Download original basic setup
        wget -q https://raw.githubusercontent.com/Consensys/linea-monorepo/main/linea-besu-package/docker/docker-compose-basic-mainnet.yaml -O docker-compose.yaml
        # Update IP address
        sed -i "s/--p2p-host=.*/--p2p-host=${PUBLIC_IP}/" docker-compose.yaml
    else
        # Download high-performance configurations
        wget -q "${BASE_URL}/docker-compose-high-performance.yaml" -O docker-compose-high-performance.yaml || {
            print_error "Failed to download high-performance configuration. Using fallback..."
            # Fallback to basic setup if high-performance config is not available
            wget -q https://raw.githubusercontent.com/Consensys/linea-monorepo/main/linea-besu-package/docker/docker-compose-basic-mainnet.yaml -O docker-compose.yaml
            sed -i "s/--p2p-host=.*/--p2p-host=${PUBLIC_IP}/" docker-compose.yaml
            SETUP_TYPE="basic"
            COMPOSE_FILE="docker-compose.yaml"
            return
        }
        
        wget -q "${BASE_URL}/nginx.conf" -O nginx.conf || print_warning "Failed to download nginx configuration"
        wget -q "${BASE_URL}/prometheus.yml" -O prometheus.yml || print_warning "Failed to download prometheus configuration"
        
        # Update IP address in docker-compose
        sed -i "s/\${PUBLIC_IP:-127.0.0.1}/${PUBLIC_IP}/g" docker-compose-high-performance.yaml
    fi
}

optimize_system() {
    if [ "$SETUP_TYPE" == "high-performance" ]; then
        print_status "Applying system optimizations for high-performance setup..."
        
        # Increase file descriptor limits
        echo "* soft nofile 1048576" | sudo tee -a /etc/security/limits.conf > /dev/null
        echo "* hard nofile 1048576" | sudo tee -a /etc/security/limits.conf > /dev/null
        
        # Optimize network settings
        sudo tee -a /etc/sysctl.conf > /dev/null << EOF

# Linea Node Optimizations
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_tw_reuse = 1
vm.swappiness = 10
EOF
        
        # Apply sysctl settings
        sudo sysctl -p > /dev/null || print_warning "Could not apply all sysctl settings"
    fi
}

start_node() {
    print_status "Starting Linea node..."
    
    # Pull images first
    sudo docker-compose -f "$COMPOSE_FILE" pull
    
    # Start the services
    sudo docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to start
    print_status "Waiting for services to start..."
    sleep 10
    
    # Check if services are running
    if [ "$SETUP_TYPE" == "high-performance" ]; then
        print_status "Checking service status..."
        sudo docker-compose -f "$COMPOSE_FILE" ps
    fi
}

print_completion_info() {
    print_status "Installation complete!"
    echo ""
    echo -e "${GREEN}=================================================================="
    echo "                    INSTALLATION SUMMARY"
    echo "=================================================================="
    echo -e "Setup Type: ${YELLOW}$SETUP_TYPE${NC}"
    echo -e "Installation Directory: ${YELLOW}$INSTALL_DIR${NC}"
    echo -e "Public IP: ${YELLOW}$PUBLIC_IP${NC}"
    echo ""
    
    if [ "$SETUP_TYPE" == "high-performance" ]; then
        echo -e "${BLUE}Available Endpoints:${NC}"
        if [ -n "$DOMAIN_NAME" ]; then
            echo "• JSON-RPC (Load Balanced): http://$DOMAIN_NAME/"
            echo "• WebSocket (Load Balanced): ws://$DOMAIN_NAME:8080/"
            echo "• Monitoring: http://$DOMAIN_NAME:9091/ (Prometheus)"
            echo "• Nginx Status: http://$DOMAIN_NAME:9090/nginx_status"
            echo ""
            echo -e "${YELLOW}Domain Configuration:${NC}"
            echo "• Domain Name: $DOMAIN_NAME"
            echo "• Make sure your DNS points to: $PUBLIC_IP"
        else
            echo "• JSON-RPC (Load Balanced): http://$PUBLIC_IP/"
            echo "• WebSocket (Load Balanced): ws://$PUBLIC_IP:8080/"
            echo "• Monitoring: http://$PUBLIC_IP:9091/ (Prometheus)"
            echo "• Nginx Status: http://$PUBLIC_IP:9090/nginx_status"
        fi
        echo ""
        echo -e "${BLUE}Performance Features:${NC}"
        echo "• Multiple Besu nodes with load balancing"
        echo "• Redis caching for improved response times"
        echo "• Rate limiting and connection management"
        echo "• Real-time monitoring with Prometheus"
        echo "• Optimized JVM settings for high throughput"
    else
        echo -e "${BLUE}Available Endpoints:${NC}"
        echo "• JSON-RPC: http://$PUBLIC_IP:8545/"
        echo "• WebSocket: ws://$PUBLIC_IP:8546/"
        echo "• P2P: $PUBLIC_IP:30303"
    fi
    
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo "• Check logs: cd $INSTALL_DIR && sudo docker-compose -f $COMPOSE_FILE logs -f"
    echo "• Stop node: cd $INSTALL_DIR && sudo docker-compose -f $COMPOSE_FILE down"
    echo "• Start node: cd $INSTALL_DIR && sudo docker-compose -f $COMPOSE_FILE up -d"
    echo "• View status: cd $INSTALL_DIR && sudo docker-compose -f $COMPOSE_FILE ps"
    if [ "$SETUP_TYPE" == "high-performance" ]; then
        echo "• Configure domain: cd $INSTALL_DIR && ./configure-domain.sh [domain]"
        echo "• Performance test: cd $INSTALL_DIR && ./benchmark.sh"
    fi
    echo ""
    echo -e "${YELLOW}Important: To use Docker without 'sudo', log out and log back in.${NC}"
    echo -e "${GREEN}=================================================================="
    echo -e "${NC}"
}

# Main execution
main() {
    print_banner
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup)
                SETUP_TYPE="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--setup basic|high-performance|development]"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # If setup type not specified via command line, prompt user
    if [ -z "$SETUP_TYPE" ]; then
        select_setup_type
    fi
    
    # Set compose file based on setup type
    case $SETUP_TYPE in
        basic)
            COMPOSE_FILE="docker-compose.yaml"
            ;;
        development)
            COMPOSE_FILE="docker-compose-dev.yaml"
            ;;
        *)
            COMPOSE_FILE="docker-compose-high-performance.yaml"
            ;;
    esac
    
    check_requirements
    install_dependencies
    setup_node_directory
    download_configurations
    configure_domain
    optimize_system
    start_node
    print_completion_info
}

# Run main function
main "$@"