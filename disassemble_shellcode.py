#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Shellcode 反汇编分析脚本
"""

# 原始字节数组
shellcode = [
    0x86, 0x87, 0x83, 0x8b, 0x75, 0x08, 0x8b, 0x7d, 0x0c, 0x85, 0xf6, 0x74, 
    0x3d, 0x85, 0xff, 0x74, 0x39, 0x80, 0x3f, 0x00, 0x74, 0x28, 0x31, 0xdb, 
    0x8a, 0x04, 0x1e, 0x32, 0xc0, 0x74, 0x2b, 0x3a, 0x07, 0x75, 0x18, 0x8d, 
    0x14, 0x1e, 0x89, 0xf9, 0x8a, 0x01, 0x32, 0xc0, 0x74, 0x17, 0x80, 0x3a, 
    0x00, 0x74, 0x17, 0x3a, 0x02, 0x75, 0x04, 0x41, 0x42, 0xeb, 0xed, 0x43, 
    0xeb, 0xda, 0xb8, 0x01, 0x00, 0x00, 0x00, 0xeb, 0x0a, 0x8d, 0x43, 0x01, 
    0xeb, 0x05, 0xb8, 0xff, 0xff, 0xff, 0xff, 0x5b, 0x5f, 0x5e, 0xc3, 0xc2, 
    0x08, 0x00
]

# 转换为字节串
shellcode_bytes = bytes(shellcode)

print("=" * 80)
print("Shellcode 分析")
print("=" * 80)
print(f"\n总长度: {len(shellcode)} 字节")
print(f"\n十六进制表示:")
print(" ".join([f"{b:02x}" for b in shellcode]))

# 尝试使用 capstone 反汇编
try:
    from capstone import *
    
    # 初始化 Capstone
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    
    print("\n" + "=" * 80)
    print("反汇编结果 (x86 32位)")
    print("=" * 80)
    
    for i in md.disasm(shellcode_bytes, 0x0):
        print(f"0x{i.address:04x}:\t{i.mnemonic}\t{i.op_str}")
        
except ImportError:
    print("\n[!] 未安装 capstone 库，尝试手动分析...")
    print("\n手动反汇编分析:")
    
    # 手动分析关键指令
    instructions = [
        (0x00, "push", "eax"),      # 86 - push eax
        (0x01, "push", "ebx"),      # 87 - push ebx  
        (0x02, "push", "ecx"),      # 83 - push ecx (实际上是 push ecx 需要 0x51, 这里可能是其他指令)
        # 继续分析...
    ]
    
    print("\n由于缺少反汇编工具，请安装 capstone:")
    print("pip install capstone")

print("\n" + "=" * 80)
print("功能分析")
print("=" * 80)

# 基于字节码模式分析
print("\n基于字节码模式分析:")
print("1. 开头有多个 push 指令 (0x86, 0x87, 0x83...) - 保存寄存器")
print("2. 包含字符串比较逻辑 (0x3a, 0x75...) - 条件跳转")
print("3. 包含循环结构 (0xeb, 0x41, 0x42...)")
print("4. 结尾有返回指令 (0xc3, 0xc2...)")

# 更详细的分析
print("\n详细分析:")
print("-" * 80)

# 分析关键字节
analysis = """
关键指令序列分析:

0x86: push eax          - 保存 eax
0x87: push ebx          - 保存 ebx  
0x83 0x75 0x08:        - 可能是 dword ptr [ebp+8] 相关操作
0x8b 0x7d 0x0c:        - mov edi, [ebp+0xc] (加载参数)
0x85 0xf6:             - test esi, esi
0x74 0x3d:             - je 0x3d (条件跳转)
0x85 0xff:             - test edi, edi  
0x74 0x39:             - je 0x39 (条件跳转)
0x80 0x3f 0x00:        - cmp byte ptr [edi], 0x00
0x74 0x28:             - je 0x28 (空字符串检查)
0x31 0xdb:             - xor ebx, ebx (清零计数器)
0x8a 0x04 0x1e:        - mov al, [esi+ebx] (加载字符)
0x32 0xc0:             - xor al, al (清零)
0x74 0x2b:             - je 0x2b (空字符检查)
0x3a 0x07:             - cmp al, [edi] (比较字符)
0x75 0x18:             - jne 0x18 (不相等跳转)
0x8d 0x14 0x1e:        - lea edx, [esi+ebx]
0x89 0xf9:             - mov ecx, edi
0x8a 0x01:             - mov al, [ecx]
0x32 0xc0:             - xor al, al
0x74 0x17:             - je 0x17
0x80 0x3a 0x00:        - cmp byte ptr [edx], 0x00
0x74 0x17:             - je 0x17
0x3a 0x02:             - cmp al, [edx]
0x75 0x04:             - jne 0x04
0x41:                  - inc ecx
0x42:                  - inc edx
0xeb 0xed:             - jmp short 0xed (循环)
0x43:                  - inc ebx (计数器+1)
0xeb 0xda:             - jmp short 0xda (继续循环)
0xb8 0x01 0x00 0x00 0x00: mov eax, 1 (eax = 1, 表示找到)
0xeb 0x0a:             - jmp short 0x0a (跳转到返回)
0x8d 0x43 0x01:        - lea eax, [ebx+1]
0xeb 0x05:             - jmp short 0x05
0xb8 0xff 0xff 0xff 0xff: mov eax, 0xffffffff (eax = -1, 表示未找到)
0x5b:                  - pop ebx (恢复寄存器)
0x5f:                  - pop edi
0x5e:                  - pop esi
0xc3:                  - ret (返回)
0xc2 0x08 0x00:        - ret 0x8 (带参数返回)
"""

print(analysis)

print("\n" + "=" * 80)
print("功能总结")
print("=" * 80)
print("""
这是一个字符串查找/比较函数 (类似 strstr 或 strchr):

功能:
1. 接收两个参数: 
   - 第一个参数 (esi): 要在其中搜索的字符串 (haystack)
   - 第二个参数 (edi): 要查找的子字符串 (needle)

2. 算法逻辑:
   - 遍历 haystack 的每个字符位置
   - 在每个位置比较 needle 是否匹配
   - 如果找到匹配，返回匹配位置的索引
   - 如果未找到，返回 -1 (0xffffffff)

3. 返回值:
   - eax = 1: 找到匹配 (在开头)
   - eax = 索引+1: 找到匹配的位置
   - eax = 0xffffffff (-1): 未找到

4. 这是一个典型的字符串搜索算法实现
""")

print("=" * 80)
print("可能的函数签名:")
print("=" * 80)
print("""
C 语言等价:
int find_string(char *haystack, char *needle) {
    // 返回 needle 在 haystack 中的位置
    // 如果找到返回索引，未找到返回 -1
}

或者更可能是:
char* strstr(const char* haystack, const char* needle) {
    // 返回 needle 在 haystack 中首次出现的位置指针
    // 如果未找到返回 NULL
}
""")