#!/bin/bash

# DeepEP/verl Configuration Information Gathering Script
# This script collects all necessary hardware and network information
# to properly configure verl with DeepEP support

OUTPUT_DIR="verl_deepep_config_info"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${OUTPUT_DIR}/deepep_config_report_${TIMESTAMP}.txt"

# Create output directory
mkdir -p ${OUTPUT_DIR}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${GREEN}================================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}================================================================${NC}"
}

# Function to run command and capture output
run_cmd() {
    local cmd="$1"
    local description="$2"
    echo -e "\n${YELLOW}>>> ${description}${NC}"
    echo "Command: ${cmd}"
    echo "---"
    eval "${cmd}" 2>&1 || echo "Command failed or not available"
}

# Function to check if command exists
check_cmd() {
    if command -v $1 &> /dev/null; then
        return 0
    else
        echo "WARNING: $1 command not found"
        return 1
    fi
}

# Start report
{
    echo "DeepEP/verl Configuration Information Report"
    echo "Generated on: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo

    # ========== SECTION 1: System Overview ==========
    print_section "1. SYSTEM OVERVIEW"
    
    run_cmd "lscpu | grep -E 'Architecture|CPU\(s\)|Thread|Core|Socket|NUMA|Model name'" \
            "CPU Information"
    
    run_cmd "free -h" "Memory Information"
    
    run_cmd "df -h | grep -E '^/dev/|^Filesystem'" "Disk Usage"

    # ========== SECTION 2: GPU Information ==========
    print_section "2. GPU INFORMATION"
    
    if check_cmd nvidia-smi; then
        run_cmd "nvidia-smi -L" "List GPUs"
        
        run_cmd "nvidia-smi --query-gpu=index,name,pci.bus_id,memory.total,compute_mode --format=csv" \
                "GPU Details"
        
        run_cmd "nvidia-smi topo -m" "GPU Topology Matrix"
        
        run_cmd "nvidia-smi topo -p2p n" "GPU P2P Capability"
        
        # Get CUDA version
        run_cmd "nvidia-smi | grep 'CUDA Version'" "CUDA Version"
    else
        echo "NVIDIA GPU tools not found"
    fi

    # ========== SECTION 3: InfiniBand/RDMA Information ==========
    print_section "3. INFINIBAND/RDMA CONFIGURATION"
    
    # Check IB devices
    if check_cmd ibv_devices; then
        run_cmd "ibv_devices" "InfiniBand Devices"
        
        run_cmd "ibv_devinfo -v" "Detailed IB Device Information"
    fi
    
    # Check IB status
    if check_cmd ibstat; then
        run_cmd "ibstat" "InfiniBand Port Status"
    fi
    
    # Check RDMA configuration
    if check_cmd rdma; then
        run_cmd "rdma link show" "RDMA Links"
        
        run_cmd "rdma dev show" "RDMA Devices"
    fi
    
    # List HCAs
    run_cmd "ls -la /sys/class/infiniband/" "Available HCAs"
    
    # Get HCA details
    echo -e "\n${YELLOW}>>> HCA Detailed Information${NC}"
    if [ -d /sys/class/infiniband ]; then
        for hca in $(ls /sys/class/infiniband/); do
            echo -e "\n--- HCA: $hca ---"
            echo "Node GUID: $(cat /sys/class/infiniband/$hca/node_guid 2>/dev/null || echo 'N/A')"
            echo "Node Description: $(cat /sys/class/infiniband/$hca/node_desc 2>/dev/null || echo 'N/A')"
            echo "Node Type: $(cat /sys/class/infiniband/$hca/node_type 2>/dev/null || echo 'N/A')"
            
            # Check ports
            if [ -d /sys/class/infiniband/$hca/ports ]; then
                for port in $(ls /sys/class/infiniband/$hca/ports/); do
                    echo "  Port $port:"
                    echo "    State: $(cat /sys/class/infiniband/$hca/ports/$port/state 2>/dev/null || echo 'N/A')"
                    echo "    Physical State: $(cat /sys/class/infiniband/$hca/ports/$port/phys_state 2>/dev/null || echo 'N/A')"
                    echo "    Rate: $(cat /sys/class/infiniband/$hca/ports/$port/rate 2>/dev/null || echo 'N/A')"
                    echo "    LID: $(cat /sys/class/infiniband/$hca/ports/$port/lid 2>/dev/null || echo 'N/A')"
                done
            fi
        done
    fi

    # ========== SECTION 4: Network Interfaces ==========
    print_section "4. NETWORK INTERFACES"
    
    run_cmd "ip addr show | grep -E '^[0-9]+:|inet |link/infiniband'" \
            "Network Interface Summary"
    
    # Detailed IB interface information
    echo -e "\n${YELLOW}>>> InfiniBand Interface Details${NC}"
    for iface in $(ip link show | grep -o "ibs[0-9]*" | sort -u); do
        echo -e "\n--- Interface: $iface ---"
        echo "MTU: $(cat /sys/class/net/$iface/mtu 2>/dev/null || echo 'N/A')"
        echo "State: $(cat /sys/class/net/$iface/operstate 2>/dev/null || echo 'N/A')"
        echo "Mode: $(cat /sys/class/net/$iface/mode 2>/dev/null || echo 'N/A')"
        if check_cmd ethtool; then
            ethtool -i $iface 2>/dev/null | grep -E "driver:|version:|firmware-version:"
        fi
    done

    # ========== SECTION 5: PCI and Atomic Operations ==========
    print_section "5. PCI DEVICES AND ATOMIC OPERATIONS"
    
    # List Mellanox devices
    run_cmd "lspci | grep -i 'mellanox\|nvidia.*infiniband'" "Mellanox/NVIDIA IB Devices"
    
    # Check atomic operations support
    echo -e "\n${YELLOW}>>> PCI Atomic Operations Support${NC}"
    for pci in $(lspci | grep -i mellanox | cut -d' ' -f1); do
        echo -e "\n--- PCI Device: $pci ---"
        lspci -vvv -s $pci 2>/dev/null | grep -E "Atomic|LnkCap|LnkSta" | grep -v "Kernel"
    done
    
    # Check MST devices
    if [ -d /dev/mst ]; then
        run_cmd "ls -la /dev/mst/" "MST Devices"
        
        # Check MLX config for atomic support
        echo -e "\n${YELLOW}>>> MLX Configuration (Atomic Operations)${NC}"
        for mst in $(ls /dev/mst/ 2>/dev/null | grep -E "mt[0-9]+_pciconf[0-9]$"); do
            echo -e "\n--- Device: /dev/mst/$mst ---"
            if check_cmd mlxconfig; then
                mlxconfig -d /dev/mst/$mst query 2>/dev/null | grep -E "PCI_ATOMIC_MODE|ATOMIC_REQ_ENABLE|PCI_WR_ORDERING" || echo "Unable to query device"
            else
                echo "mlxconfig not available"
            fi
        done
    fi

    # ========== SECTION 6: NUMA and CPU Affinity ==========
    print_section "6. NUMA TOPOLOGY AND CPU AFFINITY"
    
    if check_cmd numactl; then
        run_cmd "numactl --hardware" "NUMA Hardware Configuration"
    fi
    
    if check_cmd lstopo-no-graphics; then
        run_cmd "lstopo-no-graphics --of console" "Hardware Topology"
    elif check_cmd lstopo; then
        run_cmd "lstopo --of console" "Hardware Topology"
    fi
    
    # Get CPU-GPU affinity
    echo -e "\n${YELLOW}>>> CPU-GPU Affinity${NC}"
    if [ -d /sys/bus/pci/devices ]; then
        for gpu in $(nvidia-smi -L 2>/dev/null | grep -o "GPU-[^)]*" | head -5); do
            echo "Checking affinity for $gpu..."
        done
    fi

    # ========== SECTION 7: OFED and Driver Information ==========
    print_section "7. MELLANOX OFED AND DRIVERS"
    
    if check_cmd ofed_info; then
        run_cmd "ofed_info -s" "OFED Version"
    fi
    
    # Check kernel modules
    run_cmd "lsmod | grep -E 'mlx|ib_|rdma' | sort" "Loaded Kernel Modules"
    
    # Check driver versions
    echo -e "\n${YELLOW}>>> Driver Versions${NC}"
    for mod in mlx5_core mlx5_ib ib_core; do
        if lsmod | grep -q "^$mod"; then
            echo -n "$mod: "
            modinfo $mod 2>/dev/null | grep -E "^version:" | awk '{print $2}' || echo "version not found"
        fi
    done

    # ========== SECTION 8: InfiniBand Fabric Information ==========
    print_section "8. INFINIBAND FABRIC CONFIGURATION"
    
    if check_cmd ibnetdiscover; then
        run_cmd "ibnetdiscover -p | head -20" "IB Network Discovery (first 20 lines)"
    fi
    
    if check_cmd saquery; then
        run_cmd "saquery -s | head -20" "Service Level Query (first 20 lines)"
    fi
    
    # Check performance counters
    if check_cmd perfquery; then
        echo -e "\n${YELLOW}>>> Performance Counters Sample${NC}"
        for hca in $(ls /sys/class/infiniband/ | head -2); do
            echo "HCA: $hca"
            perfquery -l 1 2>/dev/null | head -10 || echo "Unable to query"
        done
    fi

    # ========== SECTION 9: Environment Variables ==========
    print_section "9. RELEVANT ENVIRONMENT VARIABLES"
    
    echo -e "\n${YELLOW}>>> CUDA/GPU Related${NC}"
    env | grep -E "CUDA|NVIDIA|GPU" | sort || echo "None found"
    
    echo -e "\n${YELLOW}>>> InfiniBand/RDMA Related${NC}"
    env | grep -E "MLX|RDMA|IB_|NVSHMEM" | sort || echo "None found"
    
    echo -e "\n${YELLOW}>>> MPI/Communication Related${NC}"
    env | grep -E "MPI|OMPI|UCX|NCCL" | sort || echo "None found"

    # ========== SECTION 10: DeepEP Specific Checks ==========
    print_section "10. DEEPEP SPECIFIC REQUIREMENTS"
    
    echo -e "\n${YELLOW}>>> Checking DeepEP Prerequisites${NC}"
    
    # Check for atomic operations capability
    echo -e "\n1. Atomic Operations Support:"
    atomic_support="UNKNOWN"
    if [ -d /dev/mst ]; then
        for mst in $(ls /dev/mst/ 2>/dev/null | grep -E "mt[0-9]+_pciconf[0-9]$" | head -1); do
            if check_cmd mlxconfig; then
                atomic_mode=$(mlxconfig -d /dev/mst/$mst query 2>/dev/null | grep "PCI_ATOMIC_MODE" | awk '{print $NF}')
                if [ -n "$atomic_mode" ]; then
                    atomic_support="$atomic_mode"
                    if [ "$atomic_mode" == "ENABLED(1)" ]; then
                        echo -e "${GREEN}✓ Atomic operations ENABLED${NC}"
                    else
                        echo -e "${RED}✗ Atomic operations NOT enabled: $atomic_mode${NC}"
                    fi
                fi
            fi
        done
    fi
    if [ "$atomic_support" == "UNKNOWN" ]; then
        echo -e "${YELLOW}⚠ Unable to determine atomic operations support${NC}"
    fi
    
    # Check IB connectivity
    echo -e "\n2. InfiniBand Connectivity:"
    ib_count=$(ls /sys/class/infiniband/ 2>/dev/null | wc -l)
    if [ $ib_count -gt 0 ]; then
        echo -e "${GREEN}✓ Found $ib_count InfiniBand HCA(s)${NC}"
    else
        echo -e "${RED}✗ No InfiniBand HCAs found${NC}"
    fi
    
    # Check for multiple GPUs
    echo -e "\n3. Multi-GPU Setup:"
    if check_cmd nvidia-smi; then
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
        if [ $gpu_count -gt 1 ]; then
            echo -e "${GREEN}✓ Found $gpu_count GPUs${NC}"
        else
            echo -e "${YELLOW}⚠ Only $gpu_count GPU found${NC}"
        fi
    fi

    # ========== SECTION 11: Generate Configuration Template ==========
    print_section "11. SUGGESTED VERL CONFIGURATION"
    
    echo -e "\n${YELLOW}>>> Based on detected hardware, here's a suggested configuration:${NC}"
    
    # Detect HCAs
    hcas=$(ls /sys/class/infiniband/ 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    # Detect primary IB interface
    primary_ib=$(ip addr show | grep -E "inet.*ibs" | head -1 | awk '{print $NF}')
    
    # Generate YAML config
    cat << EOF

# Suggested verl MoE/DeepEP configuration based on your hardware:
moe:
  # Core DeepEP settings
  enable_deepep: true  # Set to true if atomic operations are supported
  token_dispatcher_type: "flex"
  
  # Expert parallelism (adjust based on your model)
  expert_model_parallel_size: 8
  num_experts: 8
  
  # Routing configuration
  router_topk: 2
  router_load_balancing_type: "aux_loss"
  aux_loss_coeff: 0.01
  
  # Performance optimizations
  grouped_gemm: true
  permute_fusion: true
  
  # DeepEP network settings
  deepep:
    # Detected HCAs: ${hcas:-"NONE DETECTED"}
    hca_list: "${hcas:-mlx5_0,mlx5_1,mlx5_2,mlx5_3}"
    
    # InfiniBand service level
    ib_sl: 0
    
    # Enable adaptive routing if your fabric supports it
    adaptive_routing: false
    
    # Primary IB interface: ${primary_ib:-"NOT DETECTED"}

# Environment variables to set:
# export NVSHMEM_HCA_LIST="${hcas:-mlx5_0,mlx5_1,mlx5_2,mlx5_3}"
# export NVSHMEM_IB_SL=0
# export NVSHMEM_ENABLE_NIC_PE_MAPPING=1
# export CUDA_DEVICE_MAX_CONNECTIONS=1
EOF

    # ========== SECTION 12: Diagnostic Summary ==========
    print_section "12. DIAGNOSTIC SUMMARY"
    
    echo -e "\n${YELLOW}>>> Quick Health Check:${NC}"
    
    # Summary checks
    [ $ib_count -gt 0 ] && echo -e "${GREEN}✓ InfiniBand detected${NC}" || echo -e "${RED}✗ No InfiniBand detected${NC}"
    [ "$atomic_support" == "ENABLED(1)" ] && echo -e "${GREEN}✓ Atomic operations enabled${NC}" || echo -e "${YELLOW}⚠ Atomic operations status: $atomic_support${NC}"
    [ $gpu_count -gt 1 ] && echo -e "${GREEN}✓ Multi-GPU system${NC}" || echo -e "${YELLOW}⚠ Single GPU system${NC}"
    check_cmd mlxconfig && echo -e "${GREEN}✓ MLX tools available${NC}" || echo -e "${YELLOW}⚠ MLX tools not found${NC}"
    check_cmd ofed_info && echo -e "${GREEN}✓ OFED installed${NC}" || echo -e "${YELLOW}⚠ OFED not detected${NC}"
    
    echo -e "\n${YELLOW}>>> Action Items:${NC}"
    if [ "$atomic_support" != "ENABLED(1)" ]; then
        echo "1. Enable PCI atomic operations:"
        echo "   sudo mlxconfig -d /dev/mst/<device> set PCI_ATOMIC_MODE=1"
    fi
    
    echo -e "\n${GREEN}Report saved to: $REPORT_FILE${NC}"

} 2>&1 | tee $REPORT_FILE

# Create a summary JSON file for easier parsing
{
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"gpu_count\": \"$(nvidia-smi -L 2>/dev/null | wc -l)\","
    echo "  \"ib_devices\": \"$(ls /sys/class/infiniband/ 2>/dev/null | tr '\n' ' ')\","
    echo "  \"primary_ib_interface\": \"$(ip addr show | grep -E "inet.*ibs" | head -1 | awk '{print $NF}')\""
    echo "}"
} > ${OUTPUT_DIR}/config_summary.json

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}Data collection complete!${NC}"
echo -e "${GREEN}Files created:${NC}"
echo -e "${GREEN}  - $REPORT_FILE${NC}"
echo -e "${GREEN}  - ${OUTPUT_DIR}/config_summary.json${NC}"
echo -e "${GREEN}================================================================${NC}"
