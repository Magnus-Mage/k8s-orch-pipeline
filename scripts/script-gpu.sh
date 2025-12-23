#!/bin/bash
# GPU VM Setup Script with NVIDIA Driver Installation
# Tested on Ubuntu 22.04 with NVIDIA GPUs
# This script installs drivers, CUDA toolkit, and monitoring tools

set -e

echo "=========================================="
echo "GPU VM Setup with NVIDIA Drivers & CUDA"
echo "=========================================="

# Log everything
exec > >(tee /var/log/gpu-setup.log) 2>&1

# Update system
echo "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# Install basic tools and dependencies first
echo "🔧 Installing prerequisites..."
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
    build-essential \
    dkms \
    software-properties-common \
    pkg-config \
    linux-headers-$(uname -r) \
    gcc \
    make

# Install monitoring tools
echo "📊 Installing monitoring tools..."
apt-get install -y -qq \
    prometheus-node-exporter \
    collectd

# Check if GPU exists in hardware
echo "🔍 Checking for GPU hardware..."
if lspci | grep -i nvidia > /dev/null; then
    echo "✅ NVIDIA GPU detected in hardware:"
    lspci | grep -i nvidia
    GPU_PRESENT=true
else
    echo "⚠️  No NVIDIA GPU detected in hardware (lspci)"
    lspci | grep -i vga
    GPU_PRESENT=false
fi

# Install NVIDIA drivers if GPU is present
if [ "$GPU_PRESENT" = true ]; then
    echo "=========================================="
    echo "Installing NVIDIA Drivers"
    echo "=========================================="
    
    # Remove any existing NVIDIA installations
    echo "🧹 Cleaning up any existing NVIDIA installations..."
    apt-get remove --purge -y 'nvidia-*' 'libnvidia-*' 'cuda-*' || true
    apt-get autoremove -y || true
    
    # Add NVIDIA package repositories
    echo "📥 Adding NVIDIA package repositories..."
    
    # Add graphics drivers PPA
    add-apt-repository -y ppa:graphics-drivers/ppa
    
    # Add CUDA repository
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    rm cuda-keyring_1.1-1_all.deb
    
    apt-get update -qq
    
    # Install NVIDIA driver (latest stable)
    echo "📥 Installing NVIDIA driver (this may take 5-10 minutes)..."
    apt-get install -y -qq nvidia-driver-535 nvidia-dkms-535
    
    # Install CUDA Toolkit 12.3
    echo "📥 Installing CUDA Toolkit 12.3 (this may take 10-15 minutes)..."
    apt-get install -y -qq cuda-toolkit-12-3
    
    # Install cuDNN (optional but recommended for ML workloads)
    echo "📥 Installing cuDNN..."
    apt-get install -y -qq libcudnn8 libcudnn8-dev || echo "cuDNN install skipped (may not be available)"
    
    # Set up environment variables for CUDA
    echo "⚙️  Configuring CUDA environment variables..."
    cat >> /etc/environment << 'ENVEOF'
CUDA_HOME=/usr/local/cuda
PATH=/usr/local/cuda/bin:$PATH
LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
ENVEOF
    
    # Also add to profile.d for all users
    cat > /etc/profile.d/cuda.sh << 'PROFEOF'
export CUDA_HOME=/usr/local/cuda
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
PROFEOF
    
    chmod +x /etc/profile.d/cuda.sh
    
    # Source it for current session
    export CUDA_HOME=/usr/local/cuda
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
    
    # Create symlink if it doesn't exist
    if [ ! -L /usr/local/cuda ]; then
        ln -sf /usr/local/cuda-12.3 /usr/local/cuda
    fi
    
    # Install NVIDIA Container Toolkit (for Docker GPU support)
    echo "📥 Installing NVIDIA Container Toolkit..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
        && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    apt-get update -qq
    apt-get install -y -qq nvidia-container-toolkit
    
    # Install DCGM (Data Center GPU Manager) for monitoring
    echo "📊 Installing NVIDIA DCGM..."
    apt-get install -y -qq datacenter-gpu-manager
    
    # Enable and start DCGM
    systemctl --now enable nvidia-dcgm || echo "DCGM service config skipped"
    
    # Configure NVIDIA persistence mode
    echo "⚙️  Configuring NVIDIA persistence..."
    cat > /etc/systemd/system/nvidia-persistenced.service << 'NVPERSIST'
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user root
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced

[Install]
WantedBy=multi-user.target
NVPERSIST
    
    systemctl enable nvidia-persistenced || echo "nvidia-persistenced service enable skipped"
    
    # Load NVIDIA kernel modules
    echo "🔧 Loading NVIDIA kernel modules..."
    modprobe nvidia || echo "nvidia module will load after reboot"
    modprobe nvidia-uvm || echo "nvidia-uvm module will load after reboot"
    
    # Update initramfs
    echo "🔧 Updating initramfs..."
    update-initramfs -u
    
    # Verify installations
    echo ""
    echo "=========================================="
    echo "Verification"
    echo "=========================================="
    
    echo "NVIDIA Driver installed:"
    dpkg -l | grep nvidia-driver | head -5
    
    echo ""
    echo "CUDA Toolkit installed:"
    dpkg -l | grep cuda-toolkit | head -5
    
    echo ""
    echo "Checking if nvidia-smi is available:"
    which nvidia-smi || echo "nvidia-smi not in PATH (will be available after reboot)"
    
    echo ""
    echo "Checking if nvcc (CUDA compiler) is available:"
    which nvcc || echo "nvcc not in PATH (will be available after reboot)"
    
    # Try to run nvidia-smi (may fail before reboot)
    echo ""
    echo "Attempting to run nvidia-smi:"
    if nvidia-smi 2>/dev/null; then
        echo "✅ GPU is immediately accessible (no reboot needed)"
        REBOOT_NEEDED=false
    else
        echo "⚠️  GPU not accessible yet (reboot required to load drivers)"
        REBOOT_NEEDED=true
    fi
    
    echo "✅ NVIDIA driver and CUDA toolkit installation complete"
else
    echo "⚠️  Skipping NVIDIA driver installation (no GPU detected)"
    REBOOT_NEEDED=false
fi

# Create GPU monitoring directory
echo ""
echo "=========================================="
echo "Setting up GPU Monitoring Tools"
echo "=========================================="

mkdir -p /opt/gpu-monitor
cd /opt/gpu-monitor

# Create GPU monitoring script
cat > /opt/gpu-monitor/gpu-stats.sh << 'EOF'
#!/bin/bash
# GPU Statistics Collection Script

echo "GPU Metrics - $(date)"
echo "================================"

if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "GPU Status:"
        nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
        echo ""
        echo "Running Processes:"
        nvidia-smi pmon -c 1 2>/dev/null || nvidia-smi
    else
        echo "nvidia-smi exists but cannot communicate with driver"
        echo "Run 'sudo nvidia-smi' or reboot may be required"
    fi
else
    echo "nvidia-smi not available"
    echo "Checking hardware:"
    lspci | grep -i nvidia || echo "No NVIDIA GPU in lspci"
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
        if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            nvidia-smi --query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw,clocks.sm,clocks.mem --format=csv 2>/dev/null || nvidia-smi
        else
            echo "nvidia-smi not accessible"
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
# Wait for NVIDIA driver to be loaded
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service

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

# Create CUDA test program
cat > /opt/gpu-monitor/test-cuda.cu << 'CUDAEOF'
#include <stdio.h>
#include <cuda_runtime.h>

__global__ void hello_cuda() {
    printf("Hello from GPU thread %d!\n", threadIdx.x);
}

int main() {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    
    printf("Number of CUDA devices: %d\n\n", deviceCount);
    
    for (int i = 0; i < deviceCount; i++) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);
        printf("Device %d: %s\n", i, prop.name);
        printf("  Compute Capability: %d.%d\n", prop.major, prop.minor);
        printf("  Total Global Memory: %.2f GB\n", prop.totalGlobalMem / 1e9);
        printf("  Multiprocessors: %d\n", prop.multiProcessorCount);
        printf("  Max Threads per Block: %d\n\n", prop.maxThreadsPerBlock);
    }
    
    // Launch a simple kernel
    hello_cuda<<<1, 5>>>();
    cudaDeviceSynchronize();
    
    printf("\nCUDA test completed successfully!\n");
    return 0;
}
CUDAEOF

# Create script to compile and run CUDA test
cat > /opt/gpu-monitor/run-cuda-test.sh << 'EOF'
#!/bin/bash
echo "Compiling CUDA test program..."

if ! command -v nvcc &> /dev/null; then
    echo "ERROR: nvcc not found. Make sure CUDA is installed and in PATH."
    echo "Try: source /etc/profile.d/cuda.sh"
    exit 1
fi

cd /opt/gpu-monitor
nvcc test-cuda.cu -o test-cuda

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful"
    echo ""
    echo "Running CUDA test program..."
    ./test-cuda
else
    echo "❌ Compilation failed"
    exit 1
fi
EOF

chmod +x /opt/gpu-monitor/run-cuda-test.sh

# Create GPU stress test script
cat > /opt/gpu-monitor/gpu-stress-test.sh << 'EOF'
#!/bin/bash
# GPU Stress Test Script using CUDA samples

DURATION=${1:-60}

echo "GPU Stress Test"
echo "==============="
echo "Duration: ${DURATION} seconds"

if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found"
    exit 1
fi

if ! nvidia-smi &> /dev/null; then
    echo "ERROR: Cannot communicate with NVIDIA driver"
    exit 1
fi

echo ""
echo "GPU Information:"
nvidia-smi -L

echo ""
echo "Current GPU Status:"
nvidia-smi

echo ""
echo "To run comprehensive GPU stress test:"
echo "1. Install gpu-burn:"
echo "   cd /tmp && git clone https://github.com/wilicc/gpu-burn"
echo "   cd gpu-burn && make && ./gpu_burn $DURATION"
echo ""
echo "2. Or use CUDA samples:"
echo "   apt-get install cuda-samples-12-3"
echo "   cd /usr/local/cuda/samples/1_Utilities/deviceQuery"
echo "   make && ./deviceQuery"
echo ""
echo "3. For now, monitoring GPU during idle:"
watch -n 1 nvidia-smi
EOF

chmod +x /opt/gpu-monitor/gpu-stress-test.sh

# Create benchmark script
cat > /opt/gpu-monitor/run-benchmark.sh << 'EOF'
#!/bin/bash
# GPU Benchmark Script

echo "GPU Benchmark Runner"
echo "===================="

if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found"
    exit 1
fi

if ! nvidia-smi &> /dev/null; then
    echo "ERROR: Cannot communicate with NVIDIA driver"
    echo "Try rebooting: sudo reboot"
    exit 1
fi

echo "GPU Information:"
nvidia-smi -L
echo ""

echo "GPU Details:"
nvidia-smi --query-gpu=name,driver_version,cuda_version,memory.total --format=csv
echo ""

echo "Current GPU Status:"
nvidia-smi
echo ""

echo "=== Running Quick CUDA Test ==="
if [ -f /opt/gpu-monitor/test-cuda ]; then
    /opt/gpu-monitor/test-cuda
else
    echo "Compiling CUDA test first..."
    /opt/gpu-monitor/run-cuda-test.sh
fi

echo ""
echo "=== GPU Memory Bandwidth Test ==="
if command -v nvcc &> /dev/null && [ -d /usr/local/cuda/samples ]; then
    BANDWIDTH_TEST="/usr/local/cuda/samples/1_Utilities/bandwidthTest/bandwidthTest"
    if [ -f "$BANDWIDTH_TEST" ]; then
        $BANDWIDTH_TEST
    else
        echo "Installing CUDA samples..."
        apt-get install -y cuda-samples-12-3
        cd /usr/local/cuda/samples/1_Utilities/bandwidthTest
        make
        ./bandwidthTest
    fi
else
    echo "CUDA samples not available"
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

echo "GPU Hardware (lspci):"
lspci | grep -i nvidia || echo "No NVIDIA GPU found in lspci"
echo ""

echo "NVIDIA Packages Installed:"
dpkg -l | grep nvidia | grep ^ii | awk '{print $2}' | head -10
echo ""

if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "NVIDIA Driver Information:"
        nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1 | xargs echo "Driver Version:"
        nvidia-smi --query-gpu=cuda_version --format=csv,noheader | head -1 | xargs echo "CUDA Version:"
        echo ""
        
        echo "GPU Information:"
        nvidia-smi -L
        echo ""
        
        echo "Detailed GPU Status:"
        nvidia-smi
    else
        echo "⚠️  nvidia-smi installed but cannot communicate with driver"
        echo "Reboot required: sudo reboot"
    fi
else
    echo "❌ nvidia-smi not found in PATH"
fi

echo ""
echo "CUDA Installation:"
if command -v nvcc &> /dev/null; then
    nvcc --version
else
    echo "nvcc not in PATH. Try: source /etc/profile.d/cuda.sh"
    if [ -f /usr/local/cuda/bin/nvcc ]; then
        echo "But nvcc exists at: /usr/local/cuda/bin/nvcc"
        /usr/local/cuda/bin/nvcc --version
    fi
fi
EOF

chmod +x /opt/gpu-monitor/system-info.sh

# Create a script to check if reboot is needed
cat > /opt/gpu-monitor/check-gpu-status.sh << 'EOF'
#!/bin/bash
echo "Checking GPU Status..."
echo "====================="
echo ""

# Check if nvidia-smi exists
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ nvidia-smi not found in PATH"
    echo ""
    echo "Checking if NVIDIA driver is installed:"
    if dpkg -l | grep nvidia-driver | grep ^ii > /dev/null; then
        echo "✅ NVIDIA driver packages are installed"
        echo ""
        echo "⚠️  But nvidia-smi not in PATH. Try:"
        echo "   source /etc/profile.d/cuda.sh"
        echo "   or reboot: sudo reboot"
    else
        echo "❌ NVIDIA driver not installed"
    fi
    exit 1
fi

# Check if nvidia-smi can communicate with driver
if nvidia-smi &> /dev/null; then
    echo "✅ GPU is accessible and working!"
    echo ""
    nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv
    echo ""
    nvidia-smi
    exit 0
else
    echo "⚠️  nvidia-smi exists but cannot communicate with driver"
    echo ""
    echo "This usually means:"
    echo "  1. NVIDIA kernel modules are not loaded"
    echo "  2. A reboot is required after driver installation"
    echo ""
    echo "Checking loaded kernel modules:"
    lsmod | grep nvidia || echo "No nvidia modules loaded"
    echo ""
    echo "🔄 Reboot required. Run: sudo reboot"
    exit 1
fi
EOF

chmod +x /opt/gpu-monitor/check-gpu-status.sh

echo ""
echo "✅ GPU monitoring tools setup complete!"
echo ""

# Final status check
echo "=========================================="
echo "Final Status Check"
echo "=========================================="

/opt/gpu-monitor/system-info.sh

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Available commands:"
echo "  System info:           /opt/gpu-monitor/system-info.sh"
echo "  Check GPU status:      /opt/gpu-monitor/check-gpu-status.sh"
echo "  GPU stats (snapshot):  /opt/gpu-monitor/gpu-stats.sh"
echo "  Test CUDA:             /opt/gpu-monitor/run-cuda-test.sh"
echo "  Run benchmark:         /opt/gpu-monitor/run-benchmark.sh"
echo "  GPU stress test:       /opt/gpu-monitor/gpu-stress-test.sh"
echo "  Start monitoring:      sudo systemctl start gpu-monitor"
echo "  Enable on boot:        sudo systemctl enable gpu-monitor"
echo "  View monitoring logs:  tail -f /var/log/gpu-monitor/gpu-metrics-*.log"
echo ""
echo "Setup log saved to: /var/log/gpu-setup.log"
echo ""

if [ "$GPU_PRESENT" = true ]; then
    if [ "$REBOOT_NEEDED" = true ]; then
        echo "⚠️  ⚠️  ⚠️  REBOOT REQUIRED  ⚠️  ⚠️  ⚠️"
        echo ""
        echo "NVIDIA drivers have been installed but require a reboot to activate."
        echo ""
        echo "To complete GPU setup:"
        echo "  1. Reboot this VM: sudo reboot"
        echo "  2. After reboot, verify GPU: nvidia-smi"
        echo "  3. Test CUDA: /opt/gpu-monitor/run-cuda-test.sh"
        echo ""
        echo "For automatic reboot (happens in 2 minutes):"
        echo "  sudo shutdown -r +2 'Rebooting to activate NVIDIA drivers'"
        echo ""
    else
        echo "✅ GPU is ready to use!"
        echo "   Test it now: nvidia-smi"
    fi
fi

echo "=========================================="
