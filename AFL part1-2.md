模块1：

工具起源：由 Michał Zalewski (lcamtuf) 开发，Google维护的覆盖率引导的灰盒模糊测试工具

发展历程：2013年发布时为闭源原型，2014年开源；2017年推出AFL++分支

当前版本为2.53b

开源协议为Apache License 2.0（可以用于商业目的的模糊测试）

支持语言为C/C++

运行环境为Linux

输入变异模块位于afl-fuzz.c中，其中int main(int argc, char\*\* argv)为入口函数，fuzz_one(char\*\* argv)函数为输入变异的核心实现函数，关键数据结构queue为存储测试用例信息的链表

关联课程技术：模糊测试 Random (Fuzz) Testing

模块2：

main函数通过while ((opt = getopt(argc, argv, \"+i:o:f:m:b:t:T:dnCB:S:M:x:QV\")) \> 0)循环读取输入的命令，包括-i（输入目录）、-o（输出目录）、-f（目标文件）和其他可选设置项。输入目录指向的文件给出了初始的测试用例。

读取完命令后，程序进行初始环境设定，从输入目录读取测试用例，检查目标二进制文件的运行情况。

然后，程序进入主循环。每次循环设定当前测试用例queue_cur，并使用fuzz_one(char\*\* argv)函数对输入进行变异。

在fuzz_one(char\*\* argv)中，函数先根据当前设定和queue_cur的信息决定是否跳过当前测试用例。如果跳过，则函数直接返回。之后，函数将测试用例存入内存。接着，函数进入CALIBRATION（校准阶段），通过调用函数calibrate_case检查测试用例是否存在非确定性行为。确定测试用例稳定后进入TRIMMING阶段，使用trim_case函数去除不影响程序执行路径的字节。之后，函数进入PERFORMANCE SCORE阶段，用calculate_score函数得到测试用例变异前的表现得分，根据表现得分决定后续的变异次数。

前置准备完成后，fuzz_one对测试用例进行分为三个阶段的变异。Deterministic（确定性变异）阶段，函数尝试对输入样例进行SIMPLE BITFLIP（比特翻转）、ARITHMETIC INC/DEC（算数加减）、INTERESTING VALUES（特殊值替换，包括一些边界值）、DICTIONARY STUFF（字典变异）。Havoc（随机变异）阶段，函数执行大量可堆叠的随机变异操作，包括Flip a single bit（比特翻转）、Set byte/word/dword to interesting value（特殊值替换）、Randomly subtract from byte/word/dword（算数减法）、Randomly add to byte/word/dword（算数加法）、Set a random byte to a random value（随机值替换）、Delete bytes（删除字节）、Clone bytes (75%) or insert a block of constant bytes (25%)（字节克隆、固定块插入）、Overwrite bytes with a randomly selected chunk (75%) or fixed bytes (25%)（字节覆写、固定块覆写）、Overwrite bytes with an extra（字典字节覆写）、Insert an extra（字典插入）。SPLICING阶段，函数将当前测试用例和一个随机的测试用例进行拼接，将得到的新测试用例重新进入Havoc阶段处理。

在main函数主循环一轮执行中，fuzz_one首先进行Deterministic阶段（若当前用例已执行过一次完整的Deterministic阶段则跳过），完成Deterministic阶段后进入Havoc阶段。
若主循环遍历了一次queue队列后没有新的发现，则设置use_splicing = 1。这之后，fuzz_one中完成Havoc阶段后会进入SPLICING阶段。
在所有阶段中，变异后的用例在执行common_fuzz_stuff发现该测试用例有独特价值，会被添加到queue队列。

主循环一轮执行完成后，main函数调用write_bitmap()、write_stats_file(0, 0, 0)、save_auto()，保存位图（用于记录覆盖率）、统计文件和自动生成的字典。
