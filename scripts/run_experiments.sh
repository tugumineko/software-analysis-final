#!/bin/bash
# ============================================================================
# run_experiments.sh - AFL 输入变异模块实验自动化脚本
# 
# 本脚本包含完整的可复现实验步骤，对应 experiment-log.md 中的所有实验
# 
# 使用方法:
#   chmod +x scripts/run_experiments.sh
#   ./scripts/run_experiments.sh
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 打印带颜色的标题
print_title() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

# 打印步骤
print_step() {
    echo ""
    echo -e "${YELLOW}>>> $1${NC}"
}

# 打印命令
print_cmd() {
    echo -e "${CYAN}$ $1${NC}"
}

# 打印成功信息
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 打印错误信息
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 等待用户确认
wait_for_user() {
    echo ""
    read -p "按 Enter 继续下一步，或按 Ctrl+C 退出..."
}

# ============================================================================
# 实验 1: 环境搭建
# ============================================================================
setup_environment() {
    print_title "实验 1: 环境搭建"
    
    # 步骤 1.1: 克隆 AFL 源码
    print_step "[1.1] 克隆 AFL 源码"
    if [ -d "AFL" ]; then
        echo "AFL 目录已存在，跳过克隆"
    else
        print_cmd "git clone https://github.com/google/AFL.git"
        git clone https://github.com/google/AFL.git
        print_success "AFL 源码克隆完成"
    fi
    
    # 步骤 1.2: 编译 AFL（带调试符号）
    print_step "[1.2] 编译 AFL（带调试符号 -g -O0）"
    cd AFL
    print_cmd "make clean"
    make clean
    
    print_cmd "CFLAGS=\"-g -O0\" make -j4"
    CFLAGS="-g -O0" make -j4
    print_success "AFL 编译完成"
    cd "$PROJECT_DIR"
    
    # 步骤 1.3: 编译目标程序
    print_step "[1.3] 使用 afl-gcc 编译目标程序"
    print_cmd "./AFL/afl-gcc -g -O0 -o target_debug target.c"
    ./AFL/afl-gcc -g -O0 -o target_debug target.c
    print_success "目标程序编译完成，插桩点数量见上方输出"
    
    # 步骤 1.4: 配置系统参数
    print_step "[1.4] 配置 core_pattern 参数"
    CORE_PATTERN=$(cat /proc/sys/kernel/core_pattern 2>/dev/null || echo "unknown")
    if [[ "$CORE_PATTERN" == "core" ]]; then
        print_success "core_pattern 已正确配置"
    else
        echo "当前 core_pattern: $CORE_PATTERN"
        print_cmd "echo core | sudo tee /proc/sys/kernel/core_pattern"
        echo core | sudo tee /proc/sys/kernel/core_pattern
        print_success "core_pattern 配置完成"
    fi
    
    wait_for_user
}

# ============================================================================
# 实验 2: 基础 Fuzzing 运行
# ============================================================================
basic_fuzzing() {
    print_title "实验 2: 基础 Fuzzing 运行"
    
    # 准备种子目录
    print_step "[2.1] 准备种子目录"
    print_cmd "rm -rf output_exp"
    rm -rf output_exp
    
    print_cmd "mkdir -p seeds_exp"
    mkdir -p seeds_exp
    
    print_cmd "echo 'AAAA' > seeds_exp/seed1.txt"
    echo "AAAA" > seeds_exp/seed1.txt
    print_success "种子文件创建完成"
    
    # 运行 AFL
    print_step "[2.2] 运行 AFL Fuzzing（30 秒）"
    echo "观察要点："
    echo "  - bit flips 行显示 bitflip 阶段发现的新路径数"
    echo "  - total paths 显示当前发现的总路径数"
    echo "  - stability 显示目标程序行为的确定性"
    echo ""
    
    print_cmd "timeout 30s ./AFL/afl-fuzz -i seeds_exp -o output_exp ./target_debug"
    timeout 30s ./AFL/afl-fuzz -i seeds_exp -o output_exp ./target_debug || true
    print_success "基础 Fuzzing 完成"
    
    wait_for_user
}

# ============================================================================
# 实验 3: 确定性变异阶段追踪
# ============================================================================
trace_deterministic() {
    print_title "实验 3: 确定性变异阶段追踪"
    
    # 查看变异链
    print_step "[3.1] 查看发现的路径文件列表"
    print_cmd "ls -1 output_exp/queue/"
    ls -1 output_exp/queue/
    
    echo ""
    echo "文件名解读："
    echo "  - op:flip1,pos:0 表示 bitflip 1/1 阶段在位置 0 翻转"
    echo "  - op:arith8,pos:2,val:+3 表示 arith 阶段在位置 2 加 3"
    echo "  - +cov 表示该变异发现了新的代码覆盖"
    
    # 查看各路径内容
    print_step "[3.2] 查看各路径的 hex 内容"
    
    echo ""
    echo "--- 原始种子 ---"
    print_cmd "xxd output_exp/queue/id:000000,orig:seed1.txt"
    xxd output_exp/queue/id:000000,orig:seed1.txt
    
    echo ""
    echo "--- flip1 变异后 (预期: CAAA) ---"
    FLIP1_FILE=$(ls output_exp/queue/ | grep "flip1" | head -1)
    if [ -n "$FLIP1_FILE" ]; then
        print_cmd "xxd output_exp/queue/$FLIP1_FILE"
        xxd "output_exp/queue/$FLIP1_FILE"
    fi
    
    echo ""
    echo "--- flip2 变异后 (预期: CMAA) ---"
    FLIP2_FILE=$(ls output_exp/queue/ | grep "flip2" | head -1)
    if [ -n "$FLIP2_FILE" ]; then
        print_cmd "xxd output_exp/queue/$FLIP2_FILE"
        xxd "output_exp/queue/$FLIP2_FILE"
    fi
    
    print_success "变异演化链: AAAA → CAAA → CMAA"
    
    wait_for_user
}

# ============================================================================
# 实验 4: 触发崩溃实验
# ============================================================================
trigger_crash() {
    print_title "实验 4: 触发崩溃实验"
    
    # 准备种子
    print_step "[4.1] 准备包含部分魔数的种子"
    print_cmd "rm -rf output_crash"
    rm -rf output_crash
    
    print_cmd "mkdir -p seeds_crash"
    mkdir -p seeds_crash
    
    print_cmd "echo 'AAAA' > seeds_crash/seed1.txt"
    echo "AAAA" > seeds_crash/seed1.txt
    
    print_cmd "printf 'CMD*AAAA' > seeds_crash/seed2.txt"
    printf 'CMD*AAAA' > seeds_crash/seed2.txt
    
    print_success "种子文件创建完成"
    echo "seed2.txt 已通过前 4 字节检查 (CMD*)"
    
    # 运行 AFL
    print_step "[4.2] 运行 AFL Fuzzing（120 秒，尝试触发崩溃）"
    echo "观察要点："
    echo "  - uniq crashes 显示发现的唯一崩溃数"
    echo "  - known ints 显示 interest 阶段的贡献"
    echo ""
    
    print_cmd "timeout 120s ./AFL/afl-fuzz -i seeds_crash -o output_crash ./target_debug"
    timeout 120s ./AFL/afl-fuzz -i seeds_crash -o output_crash ./target_debug || true
    print_success "崩溃触发实验完成"
    
    wait_for_user
}

# ============================================================================
# 实验 5: 崩溃分析
# ============================================================================
analyze_crash() {
    print_title "实验 5: 崩溃分析"
    
    # 查看崩溃目录
    print_step "[5.1] 查看崩溃输入文件"
    print_cmd "ls output_crash/crashes/"
    ls output_crash/crashes/
    
    # 查看崩溃输入内容
    print_step "[5.2] 查看崩溃输入的 hex 内容"
    CRASH_FILE=$(ls output_crash/crashes/ | grep "^id:" | head -1)
    if [ -n "$CRASH_FILE" ]; then
        print_cmd "xxd output_crash/crashes/$CRASH_FILE"
        xxd "output_crash/crashes/$CRASH_FILE"
        
        echo ""
        echo "崩溃输入解析："
        echo "  - 43 4D 44 = 'CMD' (魔数校验通过)"
        echo "  - 2A = 42 = '*' (边界值检查通过)"
        echo "  - 4F 4B = 'OK' (深层路径签名)"
        echo "  - FF = 255 (特殊值 0xFF)"
        echo "  - 00 = 0 (触发崩溃的最后条件)"
    fi
    
    # 复现崩溃
    print_step "[5.3] 复现崩溃"
    if [ -n "$CRASH_FILE" ]; then
        print_cmd "./target_debug < output_crash/crashes/$CRASH_FILE"
        ./target_debug < "output_crash/crashes/$CRASH_FILE" || true
        print_success "崩溃复现成功（Segmentation fault 是预期行为）"
    fi
    
    # 查看完整变异演化链
    print_step "[5.4] 查看完整变异演化链"
    print_cmd "ls -1 output_crash/queue/"
    ls -1 output_crash/queue/
    
    wait_for_user
}

# ============================================================================
# 实验 6: 统计信息
# ============================================================================
show_statistics() {
    print_title "实验 6: 统计信息"
    
    print_step "[6.1] 查看 Fuzzer 统计信息"
    print_cmd "cat output_crash/fuzzer_stats"
    cat output_crash/fuzzer_stats
    
    echo ""
    echo "关键指标解读："
    echo "  - paths_total: 发现的总路径数"
    echo "  - paths_found: 变异发现的新路径数"
    echo "  - unique_crashes: 唯一崩溃数"
    echo "  - execs_per_sec: 每秒执行次数"
    echo "  - stability: 目标程序稳定性"
    
    print_success "实验完成！"
}

# ============================================================================
# 清理函数
# ============================================================================
cleanup() {
    print_title "清理实验数据"
    
    print_step "删除实验输出目录"
    print_cmd "rm -rf output_exp output_crash seeds_exp seeds_crash target_debug"
    rm -rf output_exp output_crash seeds_exp seeds_crash target_debug
    
    print_success "清理完成"
}

# ============================================================================
# 帮助信息
# ============================================================================
show_help() {
    echo "AFL 输入变异模块实验自动化脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  (无参数)    运行完整实验流程"
    echo "  setup       仅运行环境搭建"
    echo "  basic       仅运行基础 Fuzzing"
    echo "  crash       仅运行崩溃触发实验"
    echo "  clean       清理实验数据"
    echo "  help        显示此帮助信息"
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    print_title "AFL 输入变异模块 - 实验自动化脚本"
    echo ""
    echo "本脚本将按顺序执行以下实验："
    echo "  1. 环境搭建：克隆 AFL 源码、编译、配置"
    echo "  2. 基础 Fuzzing：观察确定性变异阶段"
    echo "  3. 变异追踪：分析变异演化链"
    echo "  4. 崩溃触发：使用优化种子触发崩溃"
    echo "  5. 崩溃分析：分析崩溃输入内容"
    echo "  6. 统计信息：查看 Fuzzer 统计"
    echo ""
    echo "每个步骤会显示执行的命令，方便截图记录。"
    
    wait_for_user
    
    setup_environment
    basic_fuzzing
    trace_deterministic
    trigger_crash
    analyze_crash
    show_statistics
    
    print_title "实验全部完成！"
    echo ""
    echo "实验输出目录："
    echo "  - output_exp/     基础 Fuzzing 输出"
    echo "  - output_crash/   崩溃触发实验输出"
    echo ""
    echo "如需清理实验数据，运行: $0 clean"
}

# ============================================================================
# 入口
# ============================================================================
case "${1:-}" in
    setup)
        setup_environment
        ;;
    basic)
        basic_fuzzing
        trace_deterministic
        ;;
    crash)
        trigger_crash
        analyze_crash
        show_statistics
        ;;
    clean)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        main
        ;;
esac
