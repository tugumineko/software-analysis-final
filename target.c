/**
 * target.c - AFL 变异引擎演示用最小化目标程序
 * 
 * 本程序专门设计用于演示 AFL 确定性变异阶段的威力：
 * - 魔数校验 (Magic Number Check): 展示 bitflip/interest 算子
 * - 边界值判断 (Boundary Check): 展示 arith 算子
 * - 嵌套条件 (Nested Conditions): 模拟真实程序的深层路径
 * 
 * 编译: afl-gcc -o target target.c
 * 运行: echo "test" | ./target
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// 全局变量用于追踪代码覆盖深度
int depth_reached = 0;

/**
 * 处理输入数据的核心函数
 * @param data 输入缓冲区
 * @param size 输入大小
 */
void process_input(const char *data, size_t size) {
    
    // =====================================================
    // 阶段 1: 魔数校验 (Magic Number Check)
    // 设计意图: 演示 AFL 的 bitflip 和 interest 算子
    // bitflip 会逐位翻转，尝试匹配 'C', 'M', 'D' 字符
    // =====================================================
    if (size < 4) {
        printf("[REJECT] Input too short (need >= 4 bytes)\n");
        return;
    }
    
    // 逐字节魔数检查 - AFL 的 bitflip 阶段会逐个破解
    if (data[0] != 'C') {
        printf("[STAGE 1] Failed: data[0] != 'C' (got: 0x%02x)\n", (unsigned char)data[0]);
        return;
    }
    depth_reached = 1;
    printf("[STAGE 1] Passed: data[0] == 'C'\n");
    
    if (data[1] != 'M') {
        printf("[STAGE 1] Failed: data[1] != 'M' (got: 0x%02x)\n", (unsigned char)data[1]);
        return;
    }
    depth_reached = 2;
    printf("[STAGE 1] Passed: data[1] == 'M'\n");
    
    if (data[2] != 'D') {
        printf("[STAGE 1] Failed: data[2] != 'D' (got: 0x%02x)\n", (unsigned char)data[2]);
        return;
    }
    depth_reached = 3;
    printf("[STAGE 1] Passed: data[2] == 'D' - Magic number 'CMD' verified!\n");
    
    // =====================================================
    // 阶段 2: 边界值判断 (Boundary Value Check)
    // 设计意图: 演示 AFL 的 arith 和 interest 算子
    // arith 会对整数进行 +1, -1 等运算，尝试匹配 42
    // interest 内置了常见边界值如 0, 1, 255, INT_MAX 等
    // =====================================================
    unsigned char length_byte = (unsigned char)data[3];
    
    if (length_byte != 42) {
        printf("[STAGE 2] Failed: length_byte != 42 (got: %d)\n", length_byte);
        return;
    }
    depth_reached = 4;
    printf("[STAGE 2] Passed: length_byte == 42 - Boundary check passed!\n");
    
    // =====================================================
    // 阶段 3: 深层路径 (Deep Path)
    // 设计意图: 需要更多条件才能触发，展示 havoc 阶段的探索能力
    // =====================================================
    if (size < 8) {
        printf("[STAGE 3] Input too short for deep path (need >= 8 bytes)\n");
        return;
    }
    
    // 检查第5-6字节是否为 "OK"
    if (data[4] == 'O' && data[5] == 'K') {
        depth_reached = 5;
        printf("[STAGE 3] Deep path: 'OK' signature found!\n");
        
        // 检查第7字节是否为特殊值 0xFF (255)
        // AFL 的 interest 阶段会尝试这个常见边界值
        if ((unsigned char)data[6] == 0xFF) {
            depth_reached = 6;
            printf("[STAGE 3] Special byte 0xFF detected!\n");
            
            // =====================================================
            // 最终触发点: 模拟漏洞
            // 当所有条件满足时，触发一个可检测的 crash
            // =====================================================
            if ((unsigned char)data[7] == 0x00) {
                depth_reached = 7;
                printf("[CRASH] All conditions met! Triggering vulnerability...\n");
                
                // 故意触发 crash (空指针解引用)
                // AFL 会将此标记为 unique crash
                char *crash_ptr = NULL;
                *crash_ptr = 'X';  // SEGFAULT!
            }
        }
    }
    
    printf("[END] Reached depth: %d/7\n", depth_reached);
}

int main(int argc, char *argv[]) {
    char buffer[1024];
    ssize_t bytes_read;
    
    // 从标准输入读取数据 (AFL 默认通过 stdin 喂数据)
    bytes_read = read(STDIN_FILENO, buffer, sizeof(buffer) - 1);
    
    if (bytes_read <= 0) {
        printf("[ERROR] No input received\n");
        return 1;
    }
    
    buffer[bytes_read] = '\0';
    printf("[INFO] Received %zd bytes of input\n", bytes_read);
    
    // 处理输入
    process_input(buffer, (size_t)bytes_read);
    
    return 0;
}
