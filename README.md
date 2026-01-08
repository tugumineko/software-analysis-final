# AFL 输入变异模块深度剖析

> 《软件分析与验证前沿》课程期末项目

## 项目简介

本项目深入剖析经典 AFL (American Fuzzy Lop) 的**输入变异机制**，通过源码分析、GDB 调试和效果验证，理解灰盒模糊测试的核心工作原理。

### 研究内容

| 阶段 | 变异策略 | 研究重点 |
|------|----------|----------|
| **Deterministic** | bitflip, arith, interest, dictionary | 确定性变异如何系统性探索输入空间 |
| **Havoc** | 随机堆叠多种算子 | 混沌变异如何突破复杂分支 |
| **Splicing** | 种子片段拼接 | 种子杂交如何组合优质基因 |

### 项目成果

- 完整的 AFL 输入变异模块源码分析（见 `AFL输入变异模块分析报告.md`）
- 可复现的调试实验记录（见 `docs/experiment-log.md`）
- 自动化实验脚本（见 `scripts/run_experiments.sh`）

---

## 环境要求

| 项目 | 版本要求 |
|------|----------|
| 操作系统 | WSL2 / Ubuntu 20.04+ |
| GCC | 9.0+ |
| GDB | 9.0+ (可选，用于源码调试) |
| Git | 2.0+ |

---

## 快速开始

### 方式一：使用自动化脚本（推荐）

```bash
# 进入项目目录 (WSL 环境)

# 添加执行权限并运行
chmod +x scripts/run_experiments.sh
./scripts/run_experiments.sh
```

脚本将自动执行以下步骤：
1. 克隆并编译 AFL 源码（带调试符号）
2. 编译目标程序 target.c
3. 配置系统参数
4. 运行基础 Fuzzing 实验
5. 运行崩溃触发实验
6. 分析变异演化链

### 方式二：手动执行

#### 1. 克隆并编译 AFL 源码

```bash
# 克隆 AFL 源码
git clone https://github.com/google/AFL.git

# 带调试符号编译 (-g -O0 便于 GDB 调试)
cd AFL
CFLAGS="-g -O0" make -j4
cd ..
```

#### 2. 编译目标程序

```bash
# 使用本地编译的 afl-gcc 编译目标程序
./AFL/afl-gcc -g -O0 -o target_debug target.c
```

#### 3. 配置系统参数

```bash
# 配置 core_pattern（AFL 要求）
echo core | sudo tee /proc/sys/kernel/core_pattern
```

#### 4. 运行基础 Fuzzing

```bash
# 准备种子目录
mkdir -p seeds_exp
echo "AAAA" > seeds_exp/seed1.txt

# 运行 AFL（30 秒）
timeout 30s ./AFL/afl-fuzz -i seeds_exp -o output_exp ./target_debug
```

#### 5. 查看变异演化链

```bash
# 查看发现的路径
ls -1 output_exp/queue/

# 查看各路径内容
xxd output_exp/queue/id:000000,orig:seed1.txt
xxd output_exp/queue/id:000001,*
```

#### 6. 触发崩溃实验

```bash
# 准备包含部分魔数的种子
mkdir -p seeds_crash
echo "AAAA" > seeds_crash/seed1.txt
printf 'CMD*AAAA' > seeds_crash/seed2.txt

# 运行 AFL（120 秒）
timeout 120s ./AFL/afl-fuzz -i seeds_crash -o output_crash ./target_debug

# 查看崩溃输入
xxd output_crash/crashes/id:*

# 复现崩溃
./target_debug < output_crash/crashes/id:*
```

---

## 目标程序设计

`target.c` 设计了多层条件检查，用于演示 AFL 各变异阶段的效果：

```
输入格式: [C][M][D][42][O][K][0xFF][0x00]
```

| 阶段 | 检查条件 | 演示变异策略 |
|------|----------|--------------|
| 阶段1 | data[0-2] = "CMD" | bitflip 算子 |
| 阶段2 | data[3] = 42 (0x2A) | arith/interest 算子 |
| 阶段3 | data[4-7] = "OK\xFF\x00" | 深层路径探索 |

当所有条件满足时，触发空指针解引用崩溃。

---

## 项目结构

```
software-analysis-final/
├── README.md                      # 本文件
├── AFL输入变异模块分析报告.md      # 完整分析报告
├── target.c                       # 目标程序源码
├── fuzz_one流程图.png             # fuzz_one 函数流程图
├── main流程图.png                 # main 函数流程图
├── docs/
│   ├── experiment-log.md          # 实验记录日志
│   ├── source-analysis.md         # 源码分析笔记
│   └── experiment-img/            # 实验截图
├── scripts/
│   └── run_experiments.sh         # 自动化实验脚本
├── seeds/                         # 初始种子文件
└── AFL/                           # AFL 源码（运行脚本后生成）
```

---

## 实验结果摘要

### 变异演化链

从种子 "AAAA" 到触发崩溃的完整演化链：

```
AAAA (原始种子)
  │ flip1,pos:0
  ▼
CAAA (发现 'C')
  │ flip2,pos:1
  ▼
CMAA (发现 'M')
  │ arith8,pos:2,val:+3
  ▼
CMDA (发现 'D')
  │ arith8,pos:3,val:-23
  ▼
CMD* (发现 42)
  │ arith8,pos:4,val:+14
  ▼
CMD*O (发现 'O')
  │ arith8,pos:5,val:+10
  ▼
CMD*OK (发现 'K')
  │ int8,pos:6,val:-1
  ▼
CMD*OK. (发现 0xFF)
  │ int16,pos:6,val:+255
  ▼
CMD*OK.. (触发崩溃!)
```

### 各阶段贡献率

| 阶段 | 发现新路径数 | 贡献率 |
|------|--------------|--------|
| bitflip | 3 | 30% |
| arith | 2 | 20% |
| interest | 2 | 20% |
| havoc | 2 | 20% |
| splice | 0 | 0% |

确定性变异阶段（bitflip + arith + interest）贡献了 **70%** 的新路径发现。

---

## 参考资料

1. [AFL 官方文档](https://afl-1.readthedocs.io/en/latest/)
2. [AFL GitHub 仓库](https://github.com/google/AFL)
3. [AFL 作者博客](https://lcamtuf.blogspot.com/2014/08/binary-fuzzing-strategies-what-works.html)
4. [AFL 源码剖析博客](https://blog.csdn.net/weixin_45651194/category_12381288.html)
---

## License

本项目仅用于教学研究目的。AFL 遵循 Apache License 2.0 开源协议。
