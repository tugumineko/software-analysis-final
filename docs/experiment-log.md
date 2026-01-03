# 实验记录日志

> 记录 AFL 变异引擎实验过程中的关键观察点和截图说明。

## 实验环境

| 项目 | 配置 |
|------|------|
| 操作系统 | WSL2 / Ubuntu 22.04 |
| AFL 版本 | TODO |
| GCC 版本 | TODO |
| 实验日期 | TODO |

---

## 实验 1: 基础 Fuzzing 运行

### 目的
验证 `target.c` 能被 AFL 正确编译和测试。

### 步骤
```bash
# 编译
afl-gcc -o target target.c

# 准备种子
mkdir seeds && echo "AAAA" > seeds/seed1.txt

# 运行
afl-fuzz -i seeds -o output ./target
```

### 预期结果
- [ ] AFL 界面正常显示
- [ ] `total paths` 数量随时间增长
- [ ] 最终应发现至少 1 个 crash

### 截图
> TODO: 插入 AFL 运行界面截图

---

## 实验 2: 观察确定性变异阶段

### 目的
观察 bitflip、arith、interest 阶段如何逐步破解 `target.c` 的条件。

### 观察点

#### Bitflip 阶段
- **stage 名称**: `bitflip 1/1`, `bitflip 8/8` 等
- **预期行为**: 逐位翻转，尝试匹配 'C', 'M', 'D' 字符
- **观察**: 当 `stage_cur` 对应字符 'C' (0x43) 的位置时，翻转后应触发新路径

#### Interest 阶段  
- **stage 名称**: `interest 8/8`, `interest 16/8` 等
- **预期行为**: 替换为边界值如 42, 0xFF 等
- **观察**: 当替换第 4 字节为 42 时，应发现新路径

### 截图
> TODO: 插入各阶段的 AFL 状态界面

---

## 实验 3: GDB 调试 fuzz_one()

### 目的
在源码级别观察变异过程。

### 步骤
```bash
# 编译 AFL 源码 (带调试符号)
cd AFL
make clean
CFLAGS="-g -O0" make

# 启动调试
gdb ./afl-fuzz

# 设置断点
(gdb) break fuzz_one
(gdb) break common_fuzz_stuff

# 运行
(gdb) run -i seeds -o output ./target
```

### 关键观察变量
- `out_buf`: 当前变异后的输入内容
- `stage_cur`: 当前变异进度
- `stage_name`: 当前变异阶段名称
- `queue_cur->fname`: 当前处理的种子文件名

### 截图
> TODO: 插入 GDB 调试界面

---

## 实验 4: 崩溃分析

### 目的
分析 AFL 发现的 crash 输入。

### 步骤
```bash
# 查看崩溃目录
ls -la output/crashes/

# 分析崩溃输入
xxd output/crashes/id:000000,*

# 复现崩溃
./target < output/crashes/id:000000,*
```

### 预期崩溃输入
根据 `target.c` 的设计，触发崩溃的输入应满足：
- 字节 0-2: `CMD` (魔数)
- 字节 3: `42` (0x2A, 边界值)
- 字节 4-5: `OK`
- 字节 6: `0xFF`
- 字节 7: `0x00`

### 截图
> TODO: 插入崩溃输入的 hexdump

---

## 数据统计

### plot_data 分析

AFL 会在 `output/plot_data` 生成统计数据，格式如下：

```
# unix_time, cycles_done, cur_path, paths_total, pending_total, pending_favs, ...
```

### 各阶段贡献率 (待填写)

| 阶段 | 发现新路径数 | 贡献率 |
|------|--------------|--------|
| bitflip | TODO | TODO |
| arith | TODO | TODO |
| interest | TODO | TODO |
| havoc | TODO | TODO |
| splice | TODO | TODO |

---

## 问题与解决

### 问题 1: TODO
**描述**: 
**解决方案**: 

### 问题 2: TODO
**描述**: 
**解决方案**: 

---

## 总结与反思

> TODO: 实验完成后填写
