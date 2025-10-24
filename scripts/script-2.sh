#!/bin/bash
# Stress Test Script - Group 2 (Medium Load - 50% CPU)

set -e

echo "=========================================="
echo "Stress Test Group 2 - Medium Load Setup"
echo "=========================================="

# Update system
echo "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# Install stress testing tools
echo "🔧 Installing stress testing tools..."
apt-get install -y -qq \
    stress-ng \
    sysstat \
    htop \
    iotop \
    nethogs \
    iftop \
    glances \
    curl \
    wget \
    net-tools \
    jq

# Install monitoring agents
echo "📊 Installing monitoring tools..."
apt-get install -y -qq \
    prometheus-node-exporter \
    collectd

# Create stress test directory
mkdir -p /opt/stress-test
cd /opt/stress-test

# Create stress configuration
cat > /opt/stress-test/stress-config.conf << 'EOF'
# Stress Test Configuration - Group 2
STRESS_LEVEL="medium"
CPU_PERCENT=50
MEMORY_PERCENT=50
IO_WORKERS=2
TIMEOUT=0  # 0 = infinite
EOF

# Create stress test runner script
cat > /opt/stress-test/run-stress.sh << 'EOF'
#!/bin/bash
source /opt/stress-test/stress-config.conf

NUM_CPUS=$(nproc)
CPU_WORKERS=$(echo "$NUM_CPUS * $CPU_PERCENT / 100" | bc)
CPU_WORKERS=${CPU_WORKERS:-1}

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
MEM_SIZE=$(echo "$TOTAL_MEM * $MEMORY_PERCENT / 100" | bc)
MEM_SIZE="${MEM_SIZE}M"

echo "Starting Stress Test - Group 2 (Medium Load)"
echo "==========================================="
echo "CPU Workers: $CPU_WORKERS (of $NUM_CPUS CPUs)"
echo "Memory: $MEM_SIZE (of ${TOTAL_MEM}M total)"
echo "I/O Workers: $IO_WORKERS"
echo "Timeout: ${TIMEOUT}s (0=infinite)"
echo "==========================================="

if [ "$TIMEOUT" -eq 0 ]; then
    stress-ng --cpu $CPU_WORKERS \
              --vm 2 --vm-bytes $MEM_SIZE \
              --io $IO_WORKERS \
              --hdd 1 \
              --metrics-brief \
              --verbose
else
    stress-ng --cpu $CPU_WORKERS \
              --vm 2 --vm-bytes $MEM_SIZE \
              --io $IO_WORKERS \
              --hdd 1 \
              --timeout ${TIMEOUT}s \
              --metrics-brief \
              --verbose
fi
EOF

chmod +x /opt/stress-test/run-stress.sh

# Create systemd service
cat > /etc/systemd/system/stress-test.service << 'EOF'
[Unit]
Description=Stress Test Service - Group 2
After=network.target

[Service]
Type=simple
ExecStart=/opt/stress-test/run-stress.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Create monitoring script
cat > /opt/stress-test/monitor.sh << 'EOF'
#!/bin/bash
echo "System Metrics - $(date)"
echo "================================"
echo "CPU Usage:"
mpstat 1 1 | tail -1
echo ""
echo "Memory Usage:"
free -h
echo ""
echo "Load Average:"
uptime
echo ""
echo "Top Processes:"
ps aux --sort=-%cpu | head -10
EOF

chmod +x /opt/stress-test/monitor.sh

# Setup log rotation
cat > /etc/logrotate.d/stress-test << 'EOF'
/var/log/stress-test.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF

echo "✅ Stress Test Group 2 setup complete!"
echo "To start stress testing: sudo systemctl start stress-test"
echo "To enable on boot: sudo systemctl enable stress-test"
echo "To monitor: /opt/stress-test/monitor.sh"
echo "=========================================="
