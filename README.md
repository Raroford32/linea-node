# Linea Node - High-Performance Installation & Management

This repository provides multiple installation options for running **Linea Besu nodes** optimized for different use cases, from basic single-node setups to **high-performance configurations** capable of handling large numbers of concurrent clients.

---

## 🚀 Quick Start

### High-Performance Setup (Recommended for Production)
Optimized for handling **1000+ concurrent clients** with load balancing, caching, and monitoring:

```bash
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-high-performance.sh | bash
```

### Basic Setup (Original)
Single node setup for development or light usage:

```bash
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-basic.sh | bash
```

---

## 📊 Performance Comparison

| Feature | Basic Setup | High-Performance Setup |
|---------|-------------|----------------------|
| **Concurrent Clients** | ~50-100 | **1000+** |
| **Request Rate** | ~100 req/s | **2000+ req/s** |
| **Load Balancing** | ❌ | ✅ Multiple nodes + Nginx |
| **Caching** | ❌ | ✅ Redis caching layer |
| **Monitoring** | ❌ | ✅ Prometheus + metrics |
| **Rate Limiting** | ❌ | ✅ DDoS protection |
| **Auto-scaling** | ❌ | ✅ Horizontal scaling ready |
| **Memory Usage** | 4GB | 16GB+ (optimized) |

---

## 🏗️ Architecture

### High-Performance Architecture
```
Internet → Nginx Load Balancer → Multiple Besu Nodes
                ↓                        ↓
              Redis Cache            Prometheus Monitoring
```

### Components:
- **Multiple Besu Nodes**: Primary and secondary nodes for redundancy
- **Nginx Load Balancer**: Distributes requests, handles rate limiting
- **Redis Cache**: Caches frequently accessed blockchain data
- **Prometheus**: Real-time monitoring and metrics
- **Optimized JVM**: Custom Java settings for maximum performance

---

## 📋 System Requirements

### Basic Setup
- **RAM**: 8GB minimum
- **Storage**: 100GB+ SSD
- **CPU**: 2+ cores
- **Network**: Stable internet connection

### High-Performance Setup  
- **RAM**: 16GB+ recommended (32GB optimal)
- **Storage**: 500GB+ NVMe SSD
- **CPU**: 8+ cores
- **Network**: High-bandwidth connection (1Gbps+)
- **OS**: Ubuntu 20.04/22.04 or Debian-based

---

## 🛠️ Installation Options

### Interactive Installation
```bash
wget https://raw.githubusercontent.com/Raroford32/linea-node/main/install-high-performance.sh
chmod +x install-high-performance.sh
./install-high-performance.sh
```

### Automated Installation
```bash
# High-performance setup
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-high-performance.sh | bash --setup high-performance

# Basic setup
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-high-performance.sh | bash --setup basic

# Development setup
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-high-performance.sh | bash --setup development
```

---

## 🌐 Domain Configuration

### Setting Up a Custom Domain

The high-performance setup supports custom domain names for easier access:

```bash
# Configure a domain during installation (interactive prompt)
# Or configure manually after installation:
cd ~/linea-node
./configure-domain.sh your-domain.com
```

### Domain Configuration Examples
```bash
# Configure a domain
./configure-domain.sh my-linea-node.com

# Configure a subdomain  
./configure-domain.sh rpc.mydomain.org

# Reset to IP-only configuration
./configure-domain.sh --reset

# View help
./configure-domain.sh --help
```

### DNS Requirements
After configuring a domain, ensure your DNS records point to your server:
- **A Record**: `your-domain.com` → `SERVER_IP_ADDRESS`
- **CNAME Record**: `www.your-domain.com` → `your-domain.com` (optional)

### Available Endpoints with Domain
- **JSON-RPC**: `http://your-domain.com/`
- **WebSocket**: `ws://your-domain.com:8080/`
- **Health Check**: `http://your-domain.com/health`
- **Monitoring**: `http://your-domain.com:9091/`

---

## 🌐 Available Endpoints

### High-Performance Setup
- **JSON-RPC (Load Balanced)**: `http://YOUR_IP/`
- **WebSocket (Load Balanced)**: `ws://YOUR_IP:8080/`
- **Prometheus Metrics**: `http://YOUR_IP:9091/`
- **Nginx Status**: `http://YOUR_IP:9090/nginx_status`
- **Health Check**: `http://YOUR_IP/health`

### Basic Setup
- **JSON-RPC**: `http://YOUR_IP:8545/`
- **WebSocket**: `ws://YOUR_IP:8546/`
- **P2P**: `YOUR_IP:30303`

---

## 📊 Performance Testing

Run the included benchmark tool to test your node's performance:

```bash
cd ~/linea-node
chmod +x benchmark.sh
./benchmark.sh
```

The benchmark tests:
- **Concurrent client handling** (10-1000 clients)
- **Request rate** and **response times**
- **Cache effectiveness**
- **Sustained load performance**
- **Error rates** under stress

Results are saved in `./benchmark_results/` with detailed HTML reports.

---

## 🔧 Management Commands

### High-Performance Setup
```bash
cd ~/linea-node

# View all services status
sudo docker-compose -f docker-compose-high-performance.yaml ps

# View logs (all services)
sudo docker-compose -f docker-compose-high-performance.yaml logs -f

# View specific service logs
sudo docker-compose -f docker-compose-high-performance.yaml logs -f linea-besu-primary
sudo docker-compose -f docker-compose-high-performance.yaml logs -f nginx-lb
sudo docker-compose -f docker-compose-high-performance.yaml logs -f redis

# Stop all services
sudo docker-compose -f docker-compose-high-performance.yaml down

# Start all services
sudo docker-compose -f docker-compose-high-performance.yaml up -d

# Restart specific service
sudo docker-compose -f docker-compose-high-performance.yaml restart nginx-lb

# Configure custom domain
./configure-domain.sh your-domain.com

# Reset to IP-only configuration
./configure-domain.sh --reset
```

### Basic Setup
```bash
cd ~/linea-node

# Check logs
sudo docker compose logs -f

# Stop node
sudo docker compose down

# Start node
sudo docker compose up -d
```

---

## 📈 Monitoring & Metrics

### Prometheus Metrics
Access Prometheus at `http://YOUR_IP:9091/` to view:
- Request rates and response times
- Node synchronization status
- System resource usage
- Cache hit/miss rates
- Error rates and uptime

### Nginx Metrics
Access Nginx status at `http://YOUR_IP:9090/nginx_status` for:
- Active connections
- Request handling statistics
- Upstream server status

### Redis Metrics
Monitor cache performance:
```bash
# Connect to Redis CLI
sudo docker exec -it linea-redis redis-cli

# View cache statistics
INFO stats
```

---

## 🚨 Troubleshooting

### Common Issues

**JVM Errors (Multiple garbage collectors selected)**
- **Fixed**: The configuration now uses only G1GC, removing conflicts with ZGC
- If you encounter this error with older versions, update your configuration

**Nginx "Host not found" Errors**
- **Fixed**: Added health checks to ensure Besu nodes are ready before nginx starts
- Services now have proper startup dependencies with health checks

**Domain Configuration**
- Use `./configure-domain.sh your-domain.com` to set up custom domain names
- Ensure your DNS points to the server's IP address
- Reset with `./configure-domain.sh --reset`

### High Memory Usage
If experiencing high memory usage:
```bash
# Check container memory usage
sudo docker stats

# Adjust JVM settings in docker-compose-high-performance.yaml
# Reduce -Xmx value for lower memory systems
```

### Connection Issues
```bash
# Check if ports are open
sudo netstat -tulpn | grep -E "(80|8080|8545|8546|30303)"

# Test connectivity
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost/
```

### Performance Issues
```bash
# Run performance test
./benchmark.sh

# Check system resources
htop
iotop

# View detailed container logs
sudo docker-compose logs --tail=100 -f
```

---

## 🔒 Security Features

- **Rate Limiting**: Prevents DDoS attacks
- **Connection Limits**: Per-IP connection restrictions  
- **CORS Configuration**: Secure cross-origin requests
- **Firewall Ready**: Easy integration with UFW/iptables
- **Resource Limits**: Container resource constraints

---

## 🔄 Scaling & Optimization

### Horizontal Scaling
Add more Besu nodes by modifying `docker-compose-high-performance.yaml`:
```yaml
  linea-besu-tertiary:
    image: consensys/linea-besu-package:latest
    # ... (copy from secondary node config)
```

### Vertical Scaling
Adjust JVM settings for your hardware:
```yaml
environment:
  - JAVA_OPTS=-Xms8g -Xmx16g  # Increase for more RAM
```

### Cache Optimization
Increase Redis memory for better caching:
```yaml
command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
```

---

## 🗂️ File Structure

```
~/linea-node/
├── docker-compose-high-performance.yaml  # Main high-perf config
├── docker-compose.yaml                   # Basic setup config
├── docker-compose-dev.yaml              # Development config
├── nginx.conf                           # Load balancer config
├── prometheus.yml                       # Monitoring config
├── benchmark.sh                         # Performance testing
├── .env                                 # Environment variables
└── benchmark_results/                   # Test results
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with the benchmark tool
4. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## ⚡ Performance Tips

1. **Use SSD storage** for blockchain data
2. **Increase system file descriptors**: `ulimit -n 65536`
3. **Optimize network settings** (done automatically by installer)
4. **Monitor resource usage** regularly
5. **Keep Docker images updated**
6. **Use connection pooling** in your applications
7. **Implement client-side caching** for frequently accessed data

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Raroford32/linea-node/issues)
- **Performance Problems**: Run `./benchmark.sh` and include results
- **System Requirements**: Check requirements section above
