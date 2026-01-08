模块1：

工具起源：由 Michał Zalewski (lcamtuf) 开发，Google维护的覆盖率引导的灰盒模糊测试工具

发展历程：2013年发布时为闭源原型，2014年开源；2017年推出AFL++分支

最新版本为2.57b

开源协议为Apache License 2.0（可以用于商业目的的模糊测试）

支持语言为C/C++

运行环境为Linux

输入变异模块位于afl-fuzz.c中，其中int main(int argc, char\*\* argv)为入口函数，fuzz_one(char\*\* argv)函数为输入变异的核心实现函数，关键数据结构queue为存储测试用例信息的链表

关联课程技术：模糊测试 Random (Fuzz) Testing

模块2：

输入变异模块用于尝试以覆盖度为指导对初始测试用例进行变异，从而获得能探索更多路径、更有可能发现漏洞的测试用例

main函数通过while ((opt = getopt(argc, argv, \"+i:o:f:m:b:t:T:dnCB:S:M:x:QV\")) \> 0)循环读取输入的命令，包括-i（输入目录）、-o（输出目录）、-f（目标文件）和其他可选设置项。输入目录指向的文件给出了初始的测试用例。

读取完命令后，程序进行初始环境设定，从输入目录读取测试用例，检查目标二进制文件的运行情况。

然后，程序进入主循环。每次循环设定当前测试用例queue_cur，并使用fuzz_one(char\*\* argv)函数对输入进行变异。

在fuzz_one(char\*\* argv)中，函数先根据当前设定和queue_cur的信息决定是否跳过当前测试用例。如果跳过，则函数直接返回。之后，函数将测试用例存入内存。接着，函数进入CALIBRATION（校准）阶段，通过调用函数calibrate_case检查测试用例是否存在非确定性行为。确定测试用例稳定，可用于测试后进入TRIMMING阶段，使用trim_case函数去除不影响程序执行路径的字节，精简测试用例。之后，函数进入PERFORMANCE SCORE阶段，用calculate_score函数得到测试用例变异前的表现得分，根据表现得分决定后续Havoc阶段的变异次数。

前置准备完成后，fuzz_one对测试用例进行分为三个阶段的变异。Deterministic（确定性变异）阶段，函数尝试对输入样例进行SIMPLE BITFLIP（比特翻转）、ARITHMETIC INC/DEC（算数加减）、INTERESTING VALUES（特殊值替换，包括一些边界值）、DICTIONARY STUFF（字典变异）。Havoc（随机变异）阶段，函数执行大量可堆叠的随机变异操作，包括Flip a single bit（比特翻转）、Set byte/word/dword to interesting value（特殊值替换）、Randomly subtract from byte/word/dword（算数减法）、Randomly add to byte/word/dword（算数加法）、Set a random byte to a random value（随机值替换）、Delete bytes（删除字节）、Clone bytes (75%) or insert a block of constant bytes (25%)（字节克隆、固定块插入）、Overwrite bytes with a randomly selected chunk (75%) or fixed bytes (25%)（字节覆写、固定块覆写）、Overwrite bytes with an extra（字典字节覆写）、Insert an extra（字典插入）。SPLICING阶段，函数将当前测试用例和一个随机的测试用例进行拼接，将得到的新测试用例重新进入Havoc阶段处理。

在main函数主循环一轮执行中，fuzz_one首先进行Deterministic阶段（若当前用例已执行过一次完整的Deterministic阶段则跳过），完成Deterministic阶段后进入Havoc阶段。
没有特殊设置的情况下，fuzz_one最开始不启用SPLICING阶段。若主循环遍历了一次queue队列后没有新的发现，则会设置use_splicing = 1。这之后，fuzz_one中完成Havoc阶段后会进入SPLICING阶段。
![fuzz_one流程图](./fuzz_one流程图.png)

在所有阶段中，变异后的用例在执行common_fuzz_stuff时若发现该变异用例有独特价值（由save_if_interesting(argv, out_buf, len, fault)函数判定），会被添加到queue队列。另外，当save_if_interesting发现用例引发崩溃时，会调用write_crash_readme函数将报错信息写入文件。
主循环一轮执行完成后，main函数调用write_bitmap()、write_stats_file(0, 0, 0)、save_auto()，保存位图（用于记录覆盖率）、统计文件和自动生成的字典。
![main流程图](./main流程图.png)

根据afl-1.readthedocs.io文档的说明，AFL运行过程中，已发现的测试用例会被定期清理，以剔除那些被更新、覆盖率更高的发现所淘汰的用例。该功能通过在主循环每次循环开始时调用cull_queue函数实现，该函数会标记覆盖率更高的测试用例为favored，其他测试用例为redundant，被标记为favored的用例在执行fuzz_one时会被更优先执行。

此外，和前文提到的一样，AFL在进行变异之前会进入TRIMMING阶段，将测试用例进行精简。该阶段使用的trim_case函数采用的是二分幂次修剪的方法。给定TRIM_START_STEPS、TRIM_END_STEPS、TRIM_MIN_BYTES，分别对应起始步长、结束步长和最小修剪块大小。函数从remove_len为用例大小除以TRIM_START_STEPS开始，尝试修剪remove_len大小的块并确认是否影响其路径覆盖（若不影响则执行修剪），每次尝试结束将remove_len除以2后继续尝试修剪，直到remove_len的步长小于结束步长或最小修剪块大小。

在使用AFL时，可以使用-x参数为其设置字典。根据文档说明，由于afl-fuzz的变异引擎是针对紧凑数据格式（例如图像、多媒体、压缩数据、正则表达式语法或 shell 脚本）优化的，对于语法特别冗长和冗余的语言不够合适，而引入外部字典可以弥补这一缺陷。