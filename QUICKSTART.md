# Quick Start Guide

## 🚀 One-Line Installation

### High-Performance Setup (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-high-performance.sh | bash
```

### Basic Setup  
```bash
curl -sSL https://raw.githubusercontent.com/Raroford32/linea-node/main/install-basic.sh | bash
```

## 📊 What You Get

### High-Performance Features:
✅ **1000+ concurrent clients** support  
✅ **2000+ requests/second** throughput  
✅ **Load balancing** across multiple nodes  
✅ **Redis caching** for faster responses  
✅ **Real-time monitoring** with Prometheus  
✅ **Rate limiting** and DDoS protection  
✅ **Auto-scaling** ready architecture  

### Endpoints After Installation:
- **JSON-RPC**: `http://YOUR_IP/`
- **WebSocket**: `ws://YOUR_IP:8080/`
- **Monitoring**: `http://YOUR_IP:9091/`
- **Health Check**: `http://YOUR_IP/health`

## 🔧 Quick Test

After installation, test your node:
```bash
# Test basic connectivity
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://YOUR_IP/

# Run performance benchmark
cd ~/linea-node && ./benchmark.sh
```

## 📱 Management Commands

```bash
cd ~/linea-node

# Check status
sudo docker-compose -f docker-compose-high-performance.yaml ps

# View logs
sudo docker-compose -f docker-compose-high-performance.yaml logs -f

# Restart services
sudo docker-compose -f docker-compose-high-performance.yaml restart
```

## 🆘 Need Help?

1. **Performance Issues**: Run `./benchmark.sh` and check results
2. **Connection Problems**: Check `http://YOUR_IP/health`
3. **High Memory Usage**: Adjust JVM settings in docker-compose file
4. **Port Conflicts**: Modify port mappings in docker-compose file

## ⚡ Performance Tips

- **Use SSD storage** for best performance
- **16GB+ RAM** recommended for high-performance setup  
- **Monitor resources**: `htop` and `iotop`
- **Keep Docker updated**: `sudo docker system prune -f`

---

**Ready to handle massive client loads? Get started now!** 🚀