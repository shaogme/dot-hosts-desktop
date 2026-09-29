#!/usr/bin/env python3
"""
patch-libkernel.py: ONLYOFFICE libkernel.so 软链接 (DT_LNK) 字体扫描修复补丁
=============================================================================

【问题背景与根本原因】
ONLYOFFICE 内部拥有两套字体/排版引擎：
1. 外层 UI 框架 (Qt5/CEF)：使用系统标准 Fontconfig 接口，正常显示中文菜单与界面。
2. 文档正文排版引擎 (CApplicationFonts)：文档编辑器正文的文字排版与矢量渲染由底层的 C++ 核心库
   负责 (libascdocumentscore.so / libgraphics.so / libkernel.so)。该核心引擎通过文件系统目录遍历
   (NSDirectory::GetFiles2) 搜寻字体。

在 Linux / NixOS 环境下，NSDirectory::GetFiles2 在遍历 dirent 时存在关键缺陷：
    call   readdir@plt
    movzbl 0x12(%rax), %eax  # dirent->d_type (偏移 0x12)
    cmp    $0x8, %al         # DT_REG (8: 普通物理文件) -> 快速分支：直接收录
    je     <add_file>
    cmp    $0x4, %al         # DT_DIR (4: 普通物理目录) -> 快速分支：递归扫描
    je     <recurse_dir>
    test   %al, %al          # DT_UNKNOWN (0: 文件系统未返回类型信息) -> 进入 stat() 判定
    jne    <readdir_loop>    # 缺陷所在：其他非 0 类型 (包括 DT_LNK = 10) 全部被跳过丢弃！

在 NixOS 中，所有系统安装的字体 (/run/current-system/sw/share/X11/fonts, /usr/share/fonts)
全部都是指向 /nix/store/... 的符号链接 (DT_LNK = 10)。
由于上述逻辑，ONLYOFFICE 正文引擎在 Linux 下扫描系统字体目录时，会直接忽略所有软链接文件与软链接子目录，
搜寻到的字体数量为 0，只能退化使用包内自带的少量西文字体 (OpenSans 等)，
导致中文文档内容全部渲染为方块/乱码 (Tofu)，字体下拉列表也选不到任何中文字体。

【补丁修补原理】
在 NSDirectory::GetFiles2 中：
将 `test %al, %al; jne <readdir_loop>` 指令 (4 字节: 84 c0 75 ..) 替换为 4 个 NOP 指令 (90 90 90 90)。
替换后：
- 当 d_type 为 DT_REG (8) 时：仍然走快速直接收录分支，性能不受影响；
- 当 d_type 为 DT_DIR (4) 时：仍然走快速目录递归分支；
- 当 d_type 为 DT_LNK (10) 或 DT_UNKNOWN (0) 等非 8/4 类型时：
  不再丢弃，而是顺序落入后方原程序已有的 stat() 判定分支。
  stat() 会自动 follow 符号链接：
    - 若目标为普通文件 (S_ISREG, 0x8000)，加入字体列表；
    - 若目标为子目录 (S_ISDIR, 0x4000)，递归进入扫描；
    - 若目标无效 (死链、socket 等)，安全跳过。

【严格校验与升级维护说明】
为防止未来版本升级时因二进制偏移或汇编结构变化导致静默失败：
1. 脚本会通过 ELF 动态符号表精确查找 `_ZN11NSDirectory9GetFiles2...` 符号范围；
2. 仅在函数体内部通过正则表达式匹配 `cmp $8 ... cmp $4 ... test %al, %al; jne ...` 指令序列；
3. 严格断言函数内匹配次数必须为 1。若未来 ONLYOFFICE 重构了此函数或指令有变，
   匹配数不为 1 将立即抛出异常并使 Nix 构建彻底失败报错，绝不带病产出；
4. 如遇构建报错，请使用 `readelf -sW libkernel.so` 与 `objdump -d` 重新比对
   `_ZN11NSDirectory9GetFiles2` 的汇编指令并更新特征模式。
"""

import os
import re
import stat
import subprocess
import sys


TARGET_SYMBOL = "_ZN11NSDirectory9GetFiles2ENSt7__cxx1112basic_stringIwSt11char_traitsIwESaIwEEERSt6vectorIS5_SaIS5_EEb"

# x86_64 汇编特征模式：
# \x3c\x08             : cmp    $0x8, %al
# \x0f\x84..\x00\x00   : je     <add_file>
# \x3c\x04             : cmp    $0x4, %al
# \x0f\x84..\x00\x00   : je     <recurse_dir>
# (\x84\xc0\x75.)      : 捕获组：test %al, %al; jne <readdir_loop>
X86_64_PATTERN = re.compile(
    b"\x3c\x08\x0f\x84..\x00\x00\x3c\x04\x0f\x84..\x00\x00(\x84\xc0\x75.)",
    re.DOTALL,
)


def patch_libkernel(libpath: str) -> None:
    if not os.path.isfile(libpath):
        raise FileNotFoundError(f"[patch-libkernel] ERROR: File not found: {libpath}")

    with open(libpath, "rb") as f:
        header = f.read(20)

    if header[:4] != b"\x7fELF":
        raise ValueError(f"[patch-libkernel] ERROR: {libpath} is not a valid ELF binary")

    # ELF 头部 offset 18 为 e_machine (2 bytes, little-endian)
    e_machine = int.from_bytes(header[18:20], "little")
    if e_machine != 0x3E:  # EM_X86_64
        raise RuntimeError(
            f"[patch-libkernel] ERROR: Unsupported ELF machine architecture: 0x{e_machine:x}. "
            "This patch is currently tailored for x86_64."
        )

    # 1. 使用 readelf 查询目标函数符号偏移与长度
    try:
        readelf_out = subprocess.check_output(
            ["readelf", "-sW", libpath], stderr=subprocess.PIPE
        ).decode("utf-8", errors="replace")
    except Exception as e:
        raise RuntimeError(f"[patch-libkernel] ERROR: Failed to run readelf on {libpath}: {e}")

    func_offset = None
    func_size = None
    for line in readelf_out.splitlines():
        if TARGET_SYMBOL in line:
            parts = line.split()
            # 格式: Num: Value Size Type Bind Vis Ndx Name
            if len(parts) >= 8:
                try:
                    func_offset = int(parts[1], 16)
                    func_size = int(parts[2])
                    break
                except ValueError:
                    pass

    if func_offset is None or func_size is None or func_size <= 0:
        raise RuntimeError(
            f"[patch-libkernel] ERROR: Target symbol '{TARGET_SYMBOL}' not found or invalid in {libpath}."
        )

    print(
        f"[patch-libkernel] Found symbol {TARGET_SYMBOL} at offset 0x{func_offset:x} (size: {func_size} bytes)"
    )

    with open(libpath, "rb") as f:
        file_bytes = f.read()

    func_bytes = file_bytes[func_offset : func_offset + func_size]

    # 2. 在目标函数范围内搜索 symlink 判断指令
    matches = list(X86_64_PATTERN.finditer(func_bytes))
    if len(matches) == 0:
        raise RuntimeError(
            f"[patch-libkernel] FATAL ERROR: Symlink skip instruction pattern not found in {TARGET_SYMBOL}.\n"
            "The ONLYOFFICE binary version may have changed or the upstream code structure was updated.\n"
            "Please disassemble libkernel.so around the symbol above to verify the new instruction pattern."
        )
    if len(matches) > 1:
        raise RuntimeError(
            f"[patch-libkernel] FATAL ERROR: Ambiguous match: found {len(matches)} occurrences of symlink pattern in {TARGET_SYMBOL}.\n"
            "Strict patching aborted to avoid corrupting the binary."
        )

    m = matches[0]
    # m.start(1) 对应捕获组 `\x84\xc0\x75.` 的起始偏移
    rel_patch_offset = m.start(1)
    abs_patch_offset = func_offset + rel_patch_offset
    orig_bytes = m.group(1)

    print(
        f"[patch-libkernel] Located patch target at file offset 0x{abs_patch_offset:x}, "
        f"original bytes: {orig_bytes.hex()} (test %al, %al; jne ...)"
    )

    # 3. 确保文件具有写入权限 (Nix 构建解包文件可能为只读)
    orig_mode = os.stat(libpath).st_mode
    os.chmod(libpath, orig_mode | stat.S_IWUSR)

    # 4. 应用补丁：将 `test %al, %al; jne ...` 替换为 4 个 NOP (0x90)
    with open(libpath, "r+b") as f:
        f.seek(abs_patch_offset)
        f.write(b"\x90\x90\x90\x90")

    # 5. 严格验证写入结果
    with open(libpath, "rb") as f:
        f.seek(abs_patch_offset)
        verify_bytes = f.read(4)

    if verify_bytes != b"\x90\x90\x90\x90":
        raise RuntimeError(
            f"[patch-libkernel] FATAL ERROR: Verification failed at 0x{abs_patch_offset:x}: "
            f"expected 90909090, but read back {verify_bytes.hex()}."
        )

    print(
        f"[patch-libkernel] SUCCESS: Successfully patched {libpath}. "
        f"Replaced {orig_bytes.hex()} with 90909090 (NOPs). DT_LNK symlinks will now fall through to stat()."
    )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path-to-libkernel.so>", file=sys.stderr)
        sys.exit(1)

    try:
        patch_libkernel(sys.argv[1])
    except Exception as err:
        print(str(err), file=sys.stderr)
        sys.exit(1)
