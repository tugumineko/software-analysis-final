#!/bin/bash
# run_experiments.sh - AFL 实验自动化脚本
# 
# 使用方法: chmod +x run_experiments.sh && ./run_experiments.sh

set -e

echo "=========================================="
echo "   AFL 变异引擎实验 - 自动化脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 AFL 是否安装
check_afl() {
    echo -e "\n${YELLOW}[1/5] 检查 AFL 安装...${NC}"
    if command -v afl-gcc &> /dev/null; then
        echo -e "${GREEN}✓ afl-gcc 已安装${NC}"
        afl-gcc --version | head -1
    else
        echo -e "${RED}✗ afl-gcc 未找到，请先安装 AFL${NC}"
        echo "  安装命令: sudo apt install afl"
        exit 1
    fi
    
    if command -v afl-fuzz &> /dev/null; then
        echo -e "${GREEN}✓ afl-fuzz 已安装${NC}"
    else
        echo -e "${RED}✗ afl-fuzz 未找到${NC}"
        exit 1
    fi
}

# 编译目标程序
compile_target() {
    echo -e "\n${YELLOW}[2/5] 编译目标程序...${NC}"
    
    if [ ! -f "target.c" ]; then
        echo -e "${RED}✗ target.c 未找到${NC}"
        exit 1
    fi
    
    afl-gcc -o target target.c
    echo -e "${GREEN}✓ 编译成功: target${NC}"
    
    # 测试运行
    echo -e "\n${YELLOW}测试运行:${NC}"
    echo "AAAA" | ./target || true
}

# 准备目录
prepare_dirs() {
    echo -e "\n${YELLOW}[3/5] 准备目录结构...${NC}"
    
    mkdir -p seeds
    mkdir -p output
    
    # 创建种子文件
    if [ ! -f "seeds/seed1.txt" ]; then
        echo "AAAA" > seeds/seed1.txt
        echo -e "${GREEN}✓ 创建种子: seeds/seed1.txt${NC}"
    fi
    
    # 可选: 创建更接近目标的种子
    echo "CMDA" > seeds/seed2.txt
    echo -e "${GREEN}✓ 创建种子: seeds/seed2.txt${NC}"
    
    # 创建接近最终答案的种子 (用于快速验证)
    printf 'CMD*OK\xff\x00' > seeds/seed3_near.bin
    echo -e "${GREEN}✓ 创建种子: seeds/seed3_near.bin (接近目标)${NC}"
}

# 配置系统
configure_system() {
    echo -e "\n${YELLOW}[4/5] 配置系统参数...${NC}"
    
    # 检查 core_pattern (AFL 需要)
    CORE_PATTERN=$(cat /proc/sys/kernel/core_pattern 2>/dev/null || echo "unknown")
    
    if [[ "$CORE_PATTERN" == "core" ]]; then
        echo -e "${GREEN}✓ core_pattern 已正确配置${NC}"
    else
        echo -e "${YELLOW}! core_pattern 当前值: $CORE_PATTERN${NC}"
        echo "  建议运行: sudo sh -c 'echo core > /proc/sys/kernel/core_pattern'"
    fi
    
    # 检查 CPU scaling (可选优化)
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "${YELLOW}  CPU governor: $GOV${NC}"
    fi
}

# 启动 Fuzzing
start_fuzzing() {
    echo -e "\n${YELLOW}[5/5] 启动 AFL Fuzzing...${NC}"
    echo "=========================================="
    echo -e "${GREEN}命令: afl-fuzz -i seeds -o output ./target${NC}"
    echo "=========================================="
    echo ""
    echo "提示:"
    echo "  - 按 Ctrl+C 停止 fuzzing"
    echo "  - 崩溃输入保存在 output/crashes/"
    echo "  - 新发现的路径在 output/queue/"
    echo ""
    
    read -p "按 Enter 开始 fuzzing，或 Ctrl+C 取消..."
    
    afl-fuzz -i seeds -o output ./target
}

# 主流程
main() {
    check_afl
    compile_target
    prepare_dirs
    configure_system
    start_fuzzing
}

# 运行
main
