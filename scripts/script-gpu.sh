#!/bin/bash
# GPU VM Setup Script
# Prepares GPU VMs for testing and monitoring

set -e

echo "=========================================="
echo "GPU VM Setup"
echo "=========================================="

# Update system
echo "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# Install basic tools
echo "🔧 Installing basic tools..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    vim \
    htop \
    sysstat \
    net-tools \
    jq \
    python3 \
    python3-pip \
    build-essential

# Install monitoring tools
echo "📊 Installing monitoring tools..."
apt-get install -y -qq \
    prometheus-node-exporter \
    collectd

# Check for GPU
echo "🔍 Checking for GPU..."
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA GPU detected"
    nvidia-smi
    
    # Install NVIDIA monitoring tools
    echo "📊 Setting up GPU monitoring..."
    
    # Install DCGM (Data Center GPU Manager) if not present
    if ! command -v dcgmi &> /dev/null; then
        echo "Installing NVIDIA DCGM..."
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
        wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-keyring_1.0-1_all.deb
        dpkg -i cuda-keyring_1.0-1_all.deb
        apt-get update
        apt-get install -y datacenter-gpu-manager
    fi
else
    echo "⚠️  No NVIDIA GPU detected or nvidia-smi not installed"
fi

# Create GPU monitoring directory
mkdir -p /opt/gpu-monitor
cd /opt/gpu-monitor

# Create GPU monitoring script
cat > /opt/gpu-monitor/gpu-stats.sh << 'EOF'
#!/bin/bash
# GPU Statistics Collection Script

echo "GPU Metrics - $(date)"
echo "================================"

if command -v nvidia-smi &> /dev/null; then
    echo "GPU Status:"
    nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
    echo ""
    echo "Running Processes:"
    nvidia-smi pmon -c 1
else
    echo "nvidia-smi not available"
fi

echo ""
echo "System Load:"
uptime
echo ""
echo "Memory Usage:"
free -h
EOF

chmod +x /opt/gpu-monitor/gpu-stats.sh

# Create continuous GPU monitoring script
cat > /opt/gpu-monitor/monitor-continuous.sh << 'EOF'
#!/bin/bash
# Continuous GPU monitoring with logging

LOG_DIR="/var/log/gpu-monitor"
mkdir -p $LOG_DIR

INTERVAL=${1:-10}  # Default 10 seconds

echo "Starting continuous GPU monitoring (interval: ${INTERVAL}s)"
echo "Logs: $LOG_DIR/gpu-metrics-$(date +%Y%m%d).log"

while true; do
    {
        echo "=== $(date) ==="
        if command -v nvidia-smi &> /dev/null; then
            nvidia-smi --query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw,clocks.sm,clocks.mem --format=csv
        fi
        echo ""
    } >> "$LOG_DIR/gpu-metrics-$(date +%Y%m%d).log"
    
    sleep $INTERVAL
done
EOF

chmod +x /opt/gpu-monitor/monitor-continuous.sh

# Create systemd service for GPU monitoring
cat > /etc/systemd/system/gpu-monitor.service << 'EOF'
[Unit]
Description=GPU Monitoring Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/gpu-monitor/monitor-continuous.sh 30
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Setup log rotation for GPU logs
cat > /etc/logrotate.d/gpu-monitor << 'EOF'
/var/log/gpu-monitor/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

# Create benchmark script placeholder
cat > /opt/gpu-monitor/run-benchmark.sh << 'EOF'
#!/bin/bash
# GPU Benchmark Script
# Add your GPU benchmarking tools here (e.g., CUDA samples, pytorch benchmarks)

echo "GPU Benchmark Runner"
echo "===================="

if command -v nvidia-smi &> /dev/null; then
    echo "GPU Information:"
    nvidia-smi -L
    echo ""
    
    # Example: Run stress test
    # gpu-burn 60  # Run for 60 seconds
    
    echo "Add your GPU benchmark commands here"
else
    echo "No GPU detected"
    exit 1
fi
EOF

chmod +x /opt/gpu-monitor/run-benchmark.sh

# Create system info script
cat > /opt/gpu-monitor/system-info.sh << 'EOF'
#!/bin/bash
echo "System Information"
echo "=================="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "CPU Cores: $(nproc)"
echo "Total RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo ""

if command -v nvidia-smi &> /dev/null; then
    echo "GPU Information:"
    nvidia-smi -L
    echo ""
    echo "CUDA Version:"
    nvidia-smi | grep "CUDA Version"
fi
EOF

chmod +x /opt/gpu-monitor/system-info.sh

echo "✅ GPU VM setup complete!"
echo ""
echo "Available commands:"
echo "  System info:           /opt/gpu-monitor/system-info.sh"
echo "  GPU stats (snapshot):  /opt/gpu-monitor/gpu-stats.sh"
echo "  Start monitoring:      sudo systemctl start gpu-monitor"
echo "  Enable on boot:        sudo systemctl enable gpu-monitor"
echo "  View monitoring logs:  tail -f /var/log/gpu-monitor/gpu-metrics-*.log"
echo "  Run benchmark:         /opt/gpu-monitor/run-benchmark.sh"
echo "=========================================="
