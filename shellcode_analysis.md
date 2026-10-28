# Shellcode 分析报告

## 基本信息
- **长度**: 86 字节
- **架构**: x86 32位
- **类型**: 字符串查找函数 (类似 `strstr`)

## 反汇编结果

```
0x0000:	xchg	byte ptr [edi + 0x8758b83], al
0x0006:	mov	edi, dword ptr [ebp + 0xc]
0x0009:	test	esi, esi
0x000b:	je	0x4a
0x000d:	test	edi, edi
0x000f:	je	0x4a
0x0011:	cmp	byte ptr [edi], 0
0x0014:	je	0x3e
0x0016:	xor	ebx, ebx
0x0018:	mov	al, byte ptr [esi + ebx]
0x001b:	xor	al, al
0x001d:	je	0x4a
0x001f:	cmp	al, byte ptr [edi]
0x0021:	jne	0x3b
0x0023:	lea	edx, [esi + ebx]
0x0026:	mov	ecx, edi
0x0028:	mov	al, byte ptr [ecx]
0x002a:	xor	al, al
0x002c:	je	0x45
0x002e:	cmp	byte ptr [edx], 0
0x0031:	je	0x4a
0x0033:	cmp	al, byte ptr [edx]
0x0035:	jne	0x3b
0x0037:	inc	ecx
0x0038:	inc	edx
0x0039:	jmp	0x28
0x003b:	inc	ebx
0x003c:	jmp	0x18
0x003e:	mov	eax, 1
0x0043:	jmp	0x4f
0x0045:	lea	eax, [ebx + 1]
0x0048:	jmp	0x4f
0x004a:	mov	eax, 0xffffffff
0x004f:	pop	ebx
0x0050:	pop	edi
0x0051:	pop	esi
0x0052:	ret
0x0053:	ret	8
```

## 功能分析

### 函数签名
```c
int find_string(const char* haystack, const char* needle);
// 或
char* strstr(const char* haystack, const char* needle);
```

### 参数说明
- **esi**: 第一个参数 - 要在其中搜索的主字符串 (haystack)
- **edi**: 第二个参数 - 要查找的子字符串 (needle)
- **ebx**: 索引计数器

### 算法逻辑

这是一个**字符串查找算法**，功能类似于 C 标准库的 `strstr()` 函数：

1. **参数验证** (0x0009-0x0014)
   - 检查 haystack 是否为 NULL
   - 检查 needle 是否为 NULL
   - 检查 needle 是否为空字符串
   - 如果任一条件成立，返回 -1 (0xffffffff)

2. **主循环** (0x0016-0x003c)
   - 使用 ebx 作为 haystack 的索引
   - 从 haystack[ebx] 开始，逐个字符比较
   - 内层循环比较 needle 的每个字符

3. **字符比较** (0x0028-0x0039)
   - 比较 needle 和 haystack 当前偏移处的字符
   - 如果所有字符都匹配，找到子串
   - 如果有字符不匹配，继续外层循环

4. **返回值** (0x003e-0x004a)
   - `eax = 1`: needle 在 haystack 开头找到
   - `eax = ebx + 1`: needle 在 haystack[ebx] 位置找到
   - `eax = 0xffffffff (-1)`: 未找到

### 关键指令解释

| 地址 | 指令 | 功能 |
|------|------|------|
| 0x0006 | `mov edi, [ebp+0xc]` | 加载第二个参数 (needle) |
| 0x0009 | `test esi, esi` | 检查第一个参数 (haystack) 是否为空 |
| 0x0016 | `xor ebx, ebx` | 清零索引计数器 |
| 0x0018 | `mov al, [esi+ebx]` | 加载 haystack[ebx] 字符 |
| 0x001f | `cmp al, [edi]` | 比较字符 |
| 0x0023 | `lea edx, [esi+ebx]` | 计算当前比较地址 |
| 0x003b | `inc ebx` | 索引+1，继续搜索 |
| 0x003e | `mov eax, 1` | 找到匹配（在位置0） |
| 0x0045 | `lea eax, [ebx+1]` | 找到匹配（在位置 ebx） |
| 0x004a | `mov eax, 0xffffffff` | 未找到，返回 -1 |

## C 语言等价实现

```c
int find_string(const char* haystack, const char* needle) {
    // 参数验证
    if (!haystack || !needle || !needle[0])
        return -1;
    
    int index = 0;
    
    while (haystack[index]) {
        // 检查从当前位置开始是否匹配 needle
        int i = 0;
        while (needle[i] && haystack[index + i] == needle[i]) {
            i++;
        }
        
        // 如果 needle 结束，说明找到完整匹配
        if (!needle[i]) {
            return index;  // 返回找到的位置
        }
        
        index++;
    }
    
    return -1;  // 未找到
}
```

## 使用场景

这段代码通常用于：
1. **字符串搜索**: 在一个长字符串中查找子串
2. **模式匹配**: 检查字符串是否包含特定模式
3. **恶意软件**: 在 shellcode 中查找 API 函数名或关键字符串

## 注意事项

- 这是一个 **32位 x86 汇编**代码
- 使用 `cdecl` 调用约定（参数在栈上）
- 返回值在 `eax` 寄存器中
- 代码体积小（86字节），适合作为 shellcode