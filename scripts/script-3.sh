#!/bin/bash
# Enhanced Stress Test Script - Group 3 (Light Load - 75% CPU)
set -e

echo "=========================================="
echo "Enhanced Stress Test Group 1 - Light Load"
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# Install comprehensive toolset
echo "Installing stress and monitoring tools..."
apt-get install -y -qq \
    stress-ng \
    sysstat \
    htop iotop nethogs iftop \
    glances \
    fio \
    iperf3 \
    sysbench \
    numactl \
    linux-tools-common linux-tools-generic \
    bpfcc-tools \
    curl wget net-tools jq bc \
    prometheus-node-exporter collectd

# Create directories
mkdir -p /opt/stress-test/{logs,benchmarks,config}
cd /opt/stress-test

# Configuration
cat > config/stress-config.conf << 'EOF'
STRESS_LEVEL="light"
CPU_PERCENT=75
MEMORY_PERCENT=70
IO_WORKERS=4
NETWORK_BANDWIDTH="10M"
DISK_IO_SIZE="512M"
TIMEOUT=0
METRICS_INTERVAL=5
EOF

# Enhanced stress runner - RUNS IN FOREGROUND for systemd simple type
cat > run-stress.sh << 'EOF'
#!/bin/bash
source /opt/stress-test/config/stress-config.conf

NUM_CPUS=$(nproc)
CPU_WORKERS=$(echo "$NUM_CPUS * $CPU_PERCENT / 100" | bc)
CPU_WORKERS=${CPU_WORKERS:-1}

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
MEM_SIZE=$(echo "$TOTAL_MEM * $MEMORY_PERCENT / 100" | bc)
MEM_SIZE="${MEM_SIZE}M"

LOG_DIR="/opt/stress-test/logs"
mkdir -p "$LOG_DIR"

echo "Enhanced Stress Test - Group 1 (Light Load)"
echo "==========================================="
echo "CPU Workers: $CPU_WORKERS (${CPU_PERCENT}% of $NUM_CPUS CPUs)"
echo "Memory: $MEM_SIZE (${MEMORY_PERCENT}% of ${TOTAL_MEM}M)"
echo "I/O Workers: $IO_WORKERS"
echo "Network Bandwidth: $NETWORK_BANDWIDTH"
echo "==========================================="

# Run stress-ng in foreground (exec replaces shell, no backgrounding)
exec stress-ng --cpu $CPU_WORKERS \
          --vm 1 --vm-bytes $MEM_SIZE \
          --io $IO_WORKERS \
          --hdd 1 --hdd-bytes 256M \
          --sock 2 \
          --timeout 0 \
          --metrics-brief \
          --syslog \
          --verbose
EOF

chmod +x run-stress.sh

# CPU Metrics Collection
cat > collect-cpu-metrics.sh << 'EOF'
#!/bin/bash
LOG_FILE="/opt/stress-test/logs/cpu-metrics-$(date +%Y%m%d).log"

{
    echo "=== CPU Metrics - $(date) ==="
    
    # CPU utilization
    mpstat -P ALL 1 1
    
    # CPU context switches and interrupts
    vmstat 1 5
    
    # Per-process CPU usage
    ps aux --sort=-%cpu | head -20
    
    # Load average and CPU info
    uptime
    cat /proc/loadavg
    
    # CPU steal time (hypervisor overhead)
    sar -u ALL 1 1
    
    echo ""
} >> "$LOG_FILE"
EOF

chmod +x collect-cpu-metrics.sh

# Memory Metrics Collection
cat > collect-memory-metrics.sh << 'EOF'
#!/bin/bash
LOG_FILE="/opt/stress-test/logs/memory-metrics-$(date +%Y%m%d).log"

{
    echo "=== Memory Metrics - $(date) ==="
    
    # Memory usage breakdown
    free -h
    vmstat -s
    
    # Memory statistics
    cat /proc/meminfo | grep -E "Mem|Swap|Cache|Buffers|Dirty|Writeback"
    
    # Page faults
    sar -B 1 1
    
    # Per-process memory
    ps aux --sort=-%mem | head -20
    
    # NUMA statistics if available
    if command -v numastat &> /dev/null; then
        numastat
    fi
    
    echo ""
} >> "$LOG_FILE"
EOF

chmod +x collect-memory-metrics.sh

# Disk I/O Metrics Collection
cat > collect-disk-metrics.sh << 'EOF'
#!/bin/bash
LOG_FILE="/opt/stress-test/logs/disk-metrics-$(date +%Y%m%d).log"

{
    echo "=== Disk I/O Metrics - $(date) ==="
    
    # Disk I/O statistics
    iostat -x 1 5
    
    # Disk queue depth and wait times
    sar -d 1 5
    
    # Per-process I/O
    iotop -b -n 1
    
    # Block device stats
    cat /proc/diskstats
    
    echo ""
} >> "$LOG_FILE"
EOF

chmod +x collect-disk-metrics.sh

# Network Metrics Collection
cat > collect-network-metrics.sh << 'EOF'
#!/bin/bash
LOG_FILE="/opt/stress-test/logs/network-metrics-$(date +%Y%m%d).log"

{
    echo "=== Network Metrics - $(date) ==="
    
    # Network interface statistics
    sar -n DEV 1 5
    
    # Network errors and drops
    ip -s link
    
    # Socket statistics
    ss -s
    
    # Connection tracking
    cat /proc/net/sockstat
    
    # Per-process network usage
    if command -v nethogs &> /dev/null; then
        timeout 5 nethogs -t -d 1 2>/dev/null || true
    fi
    
    echo ""
} >> "$LOG_FILE"
EOF

chmod +x collect-network-metrics.sh

# Comprehensive metrics collector
cat > collect-all-metrics.sh << 'EOF'
#!/bin/bash
echo "Collecting comprehensive metrics..."

/opt/stress-test/collect-cpu-metrics.sh
/opt/stress-test/collect-memory-metrics.sh
/opt/stress-test/collect-disk-metrics.sh
/opt/stress-test/collect-network-metrics.sh

echo "Metrics collected at $(date)"
EOF

chmod +x collect-all-metrics.sh

# Continuous metrics collection service
cat > monitor-continuous.sh << 'EOF'
#!/bin/bash
source /opt/stress-test/config/stress-config.conf

while true; do
    /opt/stress-test/collect-all-metrics.sh
    sleep ${METRICS_INTERVAL}
done
EOF

chmod +x monitor-continuous.sh

# Benchmark suite
cat > run-benchmarks.sh << 'EOF'
#!/bin/bash
BENCH_DIR="/opt/stress-test/benchmarks"
mkdir -p "$BENCH_DIR"
REPORT="$BENCH_DIR/benchmark-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "=== Benchmark Suite - $(date) ==="
    echo ""
    
    # CPU Benchmark
    echo "--- CPU Benchmark (sysbench) ---"
    sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run
    echo ""
    
    # Memory Bandwidth Benchmark
    echo "--- Memory Benchmark (sysbench) ---"
    sysbench memory --memory-total-size=10G --threads=$(nproc) run
    echo ""
    
    # Disk I/O Benchmark (fio)
    echo "--- Disk I/O Benchmark (fio) ---"
    fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread \
        --bs=4k --direct=1 --size=512M --numjobs=4 --runtime=30 \
        --group_reporting --filename=/tmp/fio-test
    rm -f /tmp/fio-test
    echo ""
    
    # Sequential write/read
    echo "--- Sequential I/O Test ---"
    dd if=/dev/zero of=/tmp/ddtest bs=1M count=1024 conv=fdatasync 2>&1
    dd if=/tmp/ddtest of=/dev/null bs=1M 2>&1
    rm -f /tmp/ddtest
    echo ""
    
} > "$REPORT"

echo "Benchmarks completed. Report: $REPORT"
EOF

chmod +x run-benchmarks.sh

# System info collector
cat > system-info.sh << 'EOF'
#!/bin/bash
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "CPU Model: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "CPU Cores: $(nproc)"
echo "Total RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "Swap: $(free -h | awk '/^Swap:/{print $2}')"
echo ""
echo "Network Interfaces:"
ip -br addr
echo ""
echo "Disk Space:"
df -h | grep -E '^/dev/'
EOF

chmod +x system-info.sh

# Systemd service for stress test - TYPE SIMPLE (NOT FORKING)
cat > /etc/systemd/system/stress-test.service << 'EOF'
[Unit]
Description=Enhanced Stress Test Service - Group 1
After=network.target

[Service]
Type=simple
ExecStart=/opt/stress-test/run-stress.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
KillMode=control-group

[Install]
WantedBy=multi-user.target
EOF

# Systemd service for metrics collection
cat > /etc/systemd/system/stress-metrics.service << 'EOF'
[Unit]
Description=Stress Test Metrics Collection
After=network.target

[Service]
Type=simple
ExecStart=/opt/stress-test/monitor-continuous.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Log rotation
cat > /etc/logrotate.d/stress-test << 'EOF'
/opt/stress-test/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

# Enable sysstat data collection
sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
systemctl enable sysstat
systemctl start sysstat

echo "=========================================="
echo "Enhanced Stress Test Group 1 setup complete"
echo ""
echo "Commands:"
echo "  System info:        /opt/stress-test/system-info.sh"
echo "  Start stress:       sudo systemctl start stress-test"
echo "  Start metrics:      sudo systemctl start stress-metrics"
echo "  Collect metrics:    /opt/stress-test/collect-all-metrics.sh"
echo "  Run benchmarks:     /opt/stress-test/run-benchmarks.sh"
echo "  View logs:          tail -f /opt/stress-test/logs/*"
echo "  Status:             sudo systemctl status stress-test"
echo "=========================================="
