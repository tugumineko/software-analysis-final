# AFL 变异引擎深度剖析

> 《软件分析与验证前沿》课程期末项目  

## 📋 项目简介

本项目旨在深入剖析经典 AFL (American Fuzzy Lop) 的**输入变异机制**，通过源码分析、调试实验和效果验证，理解灰盒模糊测试的核心工作原理。

### 研究内容

| 阶段 | 变异策略 | 研究重点 |
|------|----------|----------|
| **Deterministic** | bitflip, arith, interest | 确定性变异如何系统性探索输入空间 |
| **Havoc** | 随机堆叠多种算子 | 混沌变异如何突破复杂分支 |
| **Splicing** | 种子片段拼接 | 种子杂交如何组合优质基因 |

### 前沿延伸

对比分析 **AFL++** 的改进，包括 MOpt 调度优化和自定义变异器。

---

## 🔧 环境依赖

### 系统要求

- **操作系统**: WSL2 / Ubuntu 20.04+ (推荐)
- **编译器**: GCC 9.0+
- **调试器**: GDB 9.0+ (可选，用于源码调试)

### AFL 安装

```bash
# 方式 1: 通过包管理器安装 (Ubuntu)
sudo apt update
sudo apt install afl

# 方式 2: 从源码编译 (推荐，便于后续源码分析)
git clone https://github.com/google/AFL.git
cd AFL
make
sudo make install

# 验证安装
afl-fuzz --help
```

### AFL++ 安装 (可选，用于前沿对比)

```bash
git clone https://github.com/AFLplusplus/AFLplusplus.git
cd AFLplusplus
make distrib
sudo make install
```

---

## 🚀 快速开始

可直接使用自动测试脚本，在脚本的输出指导下进行逐步操作

```bash
chmod +x scripts/run_experiments.sh
./scripts/run_experiments.sh
```

### 1. 编译目标程序

使用 AFL 的插桩编译器编译 `target.c`：

```bash
# 进入项目目录
cd software-analysis-final

# 使用 afl-gcc 编译 (会自动插入覆盖率追踪代码)
afl-gcc -o target target.c

# 验证编译成功
./target < /dev/null
```

### 2. 准备种子输入

创建初始种子目录：

```bash
# 创建输入/输出目录
mkdir -p seeds crashes

# 创建一个最小种子文件
echo "AAAA" > seeds/seed1.txt

# (可选) 创建更接近目标的种子
echo "CMDA" > seeds/seed2.txt
```

### 3. 启动 Fuzzing

```bash
# 基础运行
afl-fuzz -i seeds -o crashes ./target

# 带详细输出运行
AFL_DEBUG=1 afl-fuzz -i seeds -o crashes ./target
```

---

## 📁 项目结构

```
software-analysis-final/
├── README.md              # 本文件
├── target.c               # 最小化演示目标程序
├── seeds/                 # 初始种子输入
├── crashes/               # AFL 输出目录 (自动生成)
├── docs/
│   ├── source-analysis.md # AFL 源码分析笔记
│   └── experiment-log.md  # 实验记录与截图
└── scripts/
    └── run_experiments.sh # 自动化实验脚本
```

---

## 📚 参考资料

1. **AFL 官方文档**: https://afl-1.readthedocs.io/en/latest/
2. **AFL 作者博客**: https://lcamtuf.blogspot.com/2014/08/binary-fuzzing-strategies-what-works.html  
3. **AFL 源码剖析**: https://blog.csdn.net/weixin_45651194/category_12381288.html
4. **AFL++ 官方仓库**: https://github.com/AFLplusplus/AFLplusplus
5. **AFL++ WOOT'20 论文**: Andrea Fioraldi et al., "AFL++: Combining Incremental Steps of Fuzzing Research"

---

## 👥 团队成员

| 成员 | 分工 |
|------|------|
| TODO | 环境搭建 & 实验执行 |
| TODO | 源码分析 & 文档撰写 |
| TODO | 对比实验 & 数据分析 |

---

## 📝 License

本项目仅用于教学研究目的。AFL 及 AFL++ 遵循其各自的开源许可证。
