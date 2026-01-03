# AFL 源码初步走读：变异引擎入口分析

> 本文档聚焦 AFL (google/AFL) 的变异逻辑入口

## 1. 变异逻辑的"总指挥"：`fuzz_one()` 函数

### 1.1 定位

- **源文件**: `afl-fuzz.c` (AFL 的主程序，约 8000+ 行)
- **函数名**: `fuzz_one(char** argv)` 
- **行号位置**: 约在第 5000-6500 行之间 (视版本略有差异)

### 1.2 函数签名与职责

```c
/* 
 * 对队列中的单个测试用例执行一轮完整的变异测试。
 * 返回值: 0 表示成功处理，1 表示跳过当前条目。
 */
static u8 fuzz_one(char** argv) {
    // ... 约 1500 行代码，涵盖全部变异阶段
}
```

**核心职责**：
1. 从种子队列中取出当前条目
2. 将种子内容加载到内存缓冲区
3. 依次执行 Deterministic → Havoc → Splicing 三大变异阶段
4. 每次变异后执行目标程序，收集覆盖率反馈
5. 根据反馈决定是否保存新种子

---

## 2. AFL 的 Fuzzing 主循环：从种子到变异

### 2.2 主循环简化版伪代码

```c
// afl-fuzz.c main() 中的核心循环 (约第 7800 行)
while (1) {

    // 1. 精简队列：标记"有价值"的种子
    cull_queue();

    // 2. 遍历种子队列
    queue_cur = queue;  // queue 是全局的种子链表头
    
    while (queue_cur) {
        
        // 3. 跳过已处理或低优先级的种子
        if (queue_cur->was_fuzzed && ...) {
            queue_cur = queue_cur->next;
            continue;
        }

        // 4. Core: 调用 fuzz_one() 对当前种子进行变异测试
        fuzz_one(use_argv);

        // 5. 移动到下一个种子
        queue_cur = queue_cur->next;
    }
    
    // 6. 一轮循环结束，cycle_cnt++
    queue_cycle++;
}
```

---

## 3. `fuzz_one()` 内部：变异阶段详解

### 3.1 数据准备阶段

```c
static u8 fuzz_one(char** argv) {

    // ======= 数据准备 =======
    
    // 打开当前种子文件
    fd = open(queue_cur->fname, O_RDONLY);
    
    // 获取文件大小
    len = queue_cur->len;
    
    // 分配变异缓冲区 (out_buf 是核心操作对象)
    orig_in = ck_alloc_nozero(len);
    in_buf  = ck_alloc_nozero(len);
    out_buf = ck_alloc_nozero(len);
    
    // 读取种子内容到缓冲区
    read(fd, orig_in, len);
    memcpy(in_buf, orig_in, len);
    memcpy(out_buf, in_buf, len);
    
    // out_buf 将在后续变异中被反复修改
    // ...
}
```

**关键变量**：
- `orig_in`: 原始种子内容的备份 (不会被修改)
- `in_buf`: 当前轮次的输入基准
- `out_buf`: 实际进行变异操作的缓冲区

### 3.2 确定性变异阶段 (Deterministic Stage)

这是 `fuzz_one()` 中最长的部分，约占 800+ 行代码：

```c
    // ======= 确定性变异 (约第 5100-5900 行) =======
    
    // 如果已做过或设置了跳过，则跳过确定性阶段
    if (skip_deterministic || queue_cur->was_fuzzed) 
        goto havoc_stage;

    /*******************
     * BITFLIP 阶段
     *******************/
    
    stage_name = "bitflip 1/1";  // 每次翻转 1 位，步长 1 位
    stage_max  = len << 3;       // 总共 len * 8 次尝试
    
    for (stage_cur = 0; stage_cur < stage_max; stage_cur++) {
        
        // 翻转 out_buf 中的第 stage_cur 位
        FLIP_BIT(out_buf, stage_cur);
        
        // 执行目标程序，收集反馈
        if (common_fuzz_stuff(argv, out_buf, len))
            goto abandon_entry;
        
        // 恢复翻转 (异或操作是可逆的)
        FLIP_BIT(out_buf, stage_cur);
    }

    stage_name = "bitflip 2/1";  // 每次翻转 2 位
    // ... 类似逻辑

    stage_name = "bitflip 4/1";  // 每次翻转 4 位
    // ... 类似逻辑
    
    stage_name = "bitflip 8/8";  // 每次翻转 1 字节，步长 1 字节
    // ... 类似逻辑，同时检测"自动字典"

    /*******************
     * ARITH 阶段 (算术运算)
     *******************/
    
    stage_name = "arith 8/8";
    
    for (i = 0; i < len; i++) {
        for (j = 1; j <= ARITH_MAX; j++) {  // ARITH_MAX 默认为 35
            
            // 尝试 +j
            out_buf[i] = orig_buf[i] + j;
            common_fuzz_stuff(argv, out_buf, len);
            
            // 尝试 -j  
            out_buf[i] = orig_buf[i] - j;
            common_fuzz_stuff(argv, out_buf, len);
            
            // 恢复
            out_buf[i] = orig_buf[i];
        }
    }

    // 16 位和 32 位算术运算类似...

    /*******************
     * INTEREST 阶段 (有趣值替换)
     *******************/
    
    // AFL 内置的"有趣值"列表
    static s8  interesting_8[]  = { -128, -1, 0, 1, 16, 32, 64, 100, 127 };
    static s16 interesting_16[] = { -32768, -129, 128, 255, 256, 512, 1000, 1024, 4096, 32767 };
    static s32 interesting_32[] = { -2147483648, -100663046, -32769, 32768, 65535, 65536, 100663045, 2147483647 };
    
    stage_name = "interest 8/8";
    
    for (i = 0; i < len; i++) {
        for (j = 0; j < sizeof(interesting_8); j++) {
            
            out_buf[i] = interesting_8[j];
            common_fuzz_stuff(argv, out_buf, len);
            out_buf[i] = orig_buf[i];  // 恢复
        }
    }

    // 16 位和 32 位有趣值替换类似...
```

### 3.3 Havoc 阶段 (混沌变异)

```c
havoc_stage:
    
    // ======= Havoc 阶段 (约第 5900-6200 行) =======
    
    stage_name = "havoc";
    stage_max  = HAVOC_CYCLES * perf_score / 100;  // 根据种子"能量"调整次数
    
    for (stage_cur = 0; stage_cur < stage_max; stage_cur++) {
        
        // 随机决定本轮堆叠多少个变异操作
        u32 use_stacking = 1 << (1 + UR(HAVOC_STACK_POW2));
        
        for (i = 0; i < use_stacking; i++) {
            
            // 随机选择一种变异操作 (共 15+ 种)
            switch (UR(15 + ((extras_cnt + a_extras_cnt) ? 2 : 0))) {
                
                case 0:  // 翻转随机位
                    FLIP_BIT(out_buf, UR(temp_len << 3));
                    break;
                    
                case 1:  // 替换为有趣值 (8位)
                    out_buf[UR(temp_len)] = interesting_8[UR(sizeof(interesting_8))];
                    break;
                    
                case 2:  // 替换为有趣值 (16位)
                    *(u16*)(out_buf + UR(temp_len - 1)) = interesting_16[UR(...)];
                    break;
                    
                case 3:  // 随机减法 (8位)
                    out_buf[UR(temp_len)] -= 1 + UR(ARITH_MAX);
                    break;
                    
                case 4:  // 随机加法 (8位)
                    out_buf[UR(temp_len)] += 1 + UR(ARITH_MAX);
                    break;
                    
                // ... 更多操作: 随机字节、删除、插入、覆盖等
                
                case 13: // 删除一段字节
                    del_from = UR(temp_len);
                    del_len  = choose_block_len(temp_len - del_from);
                    memmove(out_buf + del_from, 
                            out_buf + del_from + del_len,
                            temp_len - del_from - del_len);
                    temp_len -= del_len;
                    break;
                    
                case 14: // 克隆并插入一段字节
                    // ...
                    break;
            }
        }
        
        // 执行变异后的输入
        common_fuzz_stuff(argv, out_buf, temp_len);
        
        // 恢复 out_buf 为原始状态，准备下一轮
        memcpy(out_buf, in_buf, len);
        temp_len = len;
    }
```

### 3.4 Splicing 阶段 (种子拼接)

```c
    // ======= Splicing 阶段 (约第 6200-6350 行) =======
    
    if (!splice_cycle++) {
        
        stage_name = "splice";
        
        // 最多尝试 SPLICE_CYCLES 次 (默认 15)
        for (splice_cycle = 0; splice_cycle < SPLICE_CYCLES; splice_cycle++) {
            
            // 1. 随机选择队列中的另一个种子
            target = queue;
            tid = UR(queued_paths);
            while (tid--) target = target->next;
            
            // 跳过自身或长度为0的种子
            if (target == queue_cur || !target->len) continue;
            
            // 2. 读取目标种子内容
            new_buf = ck_alloc_nozero(target->len);
            read(fd, new_buf, target->len);
            
            // 3. 定位两个种子的第一个差异点
            locate_diffs(in_buf, new_buf, MIN(len, target->len), &f_diff, &l_diff);
            
            // 4. 在差异区域选择一个拼接点
            split_at = f_diff + UR(l_diff - f_diff);
            
            // 5. 执行拼接: 前半部分来自当前种子，后半部分来自目标种子
            memcpy(out_buf, in_buf, split_at);
            memcpy(out_buf + split_at, new_buf + split_at, target->len - split_at);
            
            // 6. 对拼接结果再做一轮 Havoc
            goto havoc_stage;
        }
    }

    // 标记当前种子已完成 fuzz
    queue_cur->was_fuzzed = 1;
    
    return 0;  // 成功处理
}
```

---

## 4. 关键辅助函数

### 4.1 `common_fuzz_stuff()` - 执行目标并收集反馈

```c
static u8 common_fuzz_stuff(char** argv, u8* out_buf, u32 len) {
    
    // 1. 将变异后的数据写入临时文件 (或通过共享内存传递)
    write_to_testcase(out_buf, len);
    
    // 2. 执行目标程序
    fault = run_target(argv, exec_tmout);
    
    // 3. 检查执行结果
    if (fault == FAULT_TMOUT) { ... }   // 超时
    if (fault == FAULT_CRASH) { ... }   // 崩溃
    
    // 4. 检查覆盖率位图是否有新路径
    queued_discovered += save_if_interesting(argv, out_buf, len, fault);
    
    return 0;
}
```

### 4.2 `save_if_interesting()` - 新路径判定

```c
static u8 save_if_interesting(char** argv, void* mem, u32 len, u8 fault) {
    
    // 比较当前执行的覆盖率位图与全局位图
    u8 hnb = has_new_bits(virgin_bits);
    
    if (!hnb) {
        // 没有新覆盖，丢弃
        return 0;
    }
    
    // 发现新路径！添加到队列
    add_to_queue(queue_fn, mem, len, ...);
    
    // 如果是崩溃，保存到 crashes 目录
    if (fault == FAULT_CRASH) {
        unique_crashes++;
        write_crash_to_disk(...);
    }
    
    return 1;  // 表示发现了有趣的输入
}
```
