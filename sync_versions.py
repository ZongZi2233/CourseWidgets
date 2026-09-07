#!/usr/bin/env python3
"""
版本同步与自动化管理脚本 (Unified Version Synchronization Tool)
支持：
1. 默认无参运行：从 lib/constants/version.dart 读取，同步至 pubspec.yaml、Runner.rc、README 等
2. 带参数运行：python sync_versions.py <version> <build_number>
   例如：python sync_versions.py 2.6.0 10008033
3. 自动同步 README.md / README_EN.md 的版本徽章
4. 验证全平台版本号一致性
"""

import sys
import re
import os

# 确保在 Windows GBK 控制台下输出不会因为特殊字符报错
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

VERSION_DART = os.path.join(ROOT_DIR, "lib", "constants", "version.dart")
PUBSPEC_YAML = os.path.join(ROOT_DIR, "pubspec.yaml")
WINDOWS_RC = os.path.join(ROOT_DIR, "windows", "runner", "Runner.rc")
README_CN = os.path.join(ROOT_DIR, "README.md")
README_EN = os.path.join(ROOT_DIR, "README_EN.md")

def read_dart_version():
    """读取 Dart 版本常量"""
    with open(VERSION_DART, 'r', encoding='utf-8') as f:
        content = f.read()
    
    app_version = re.search(r"const String appVersion = '([^']+)'", content)
    build_number = re.search(r"const int buildNumber = (\d+)", content)
    
    if app_version and build_number:
        return app_version.group(1), int(build_number.group(1))
    else:
        raise ValueError("无法在 lib/constants/version.dart 中解析版本常量")

def write_dart_version(version, build_number):
    """更新 Dart 版本常量"""
    with open(VERSION_DART, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = re.sub(
        r"const String appVersion = '[^']+';",
        f"const String appVersion = '{version}';",
        content
    )
    content = re.sub(
        r"const int buildNumber = \d+;",
        f"const int buildNumber = {build_number};",
        content
    )
    
    with open(VERSION_DART, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] version.dart 已更新: {version} ({build_number})")

def update_pubspec(version, build_number):
    """更新 pubspec.yaml"""
    with open(PUBSPEC_YAML, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = re.sub(
        r'version:\s*[\d\w.-]+\+\d+',
        f'version: {version}+{build_number}',
        content
    )
    
    with open(PUBSPEC_YAML, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] pubspec.yaml 已更新: {version}+{build_number}")

def update_windows_config(version, build_number):
    """更新 Windows Runner.rc 配置"""
    if not os.path.exists(WINDOWS_RC):
        return
    
    with open(WINDOWS_RC, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 提取纯数字版本元组用于 VERSION_AS_NUMBER
    # 比如 2.6.0 -> 2,6,0,0
    clean_ver = version.split('-')[0].split('+')[0]
    parts = clean_ver.split('.')
    while len(parts) < 4:
        parts.append('0')
    ver_number_str = ",".join(parts[:4])
    
    content = re.sub(
        r'#define VERSION_AS_NUMBER [\d,]+',
        f'#define VERSION_AS_NUMBER {ver_number_str}',
        content
    )
    content = re.sub(
        r'#define VERSION_AS_STRING "[^"]+"',
        f'#define VERSION_AS_STRING "{version}"',
        content
    )
    
    with open(WINDOWS_RC, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] Windows Runner.rc 已更新: {version} ({ver_number_str})")

def update_readme_badges(version):
    """更新中英文 README 的版本 Badge"""
    badge_pattern = r'\[!\[Version\]\(https://img\.shields\.io/badge/Version-[^)]+-FF9BAE\)\]'
    new_badge = f'[![Version](https://img.shields.io/badge/Version-{version}-FF9BAE)]'
    
    for readme_path, name in [(README_CN, "README.md"), (README_EN, "README_EN.md")]:
        if os.path.exists(readme_path):
            with open(readme_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            content = re.sub(badge_pattern, new_badge, content)
            
            with open(readme_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"[OK] {name} 徽章已更新: {version}")

def verify_all(version, build_number):
    """验证所有文件中的版本一致性"""
    print("\n[版本一致性校验]")
    # 1. version.dart
    v_dart, b_dart = read_dart_version()
    assert v_dart == version and b_dart == build_number, f"version.dart mismatch: {v_dart} != {version}"
    print(f"  • version.dart: {v_dart}+{b_dart} (一致)")
    
    # 2. pubspec.yaml
    with open(PUBSPEC_YAML, 'r', encoding='utf-8') as f:
        p_content = f.read()
    assert f"version: {version}+{build_number}" in p_content, "pubspec.yaml mismatch"
    print(f"  • pubspec.yaml: {version}+{build_number} (一致)")
    
    # 3. Windows
    if os.path.exists(WINDOWS_RC):
        with open(WINDOWS_RC, 'r', encoding='utf-8') as f:
            w_content = f.read()
        assert f'#define VERSION_AS_STRING "{version}"' in w_content, "Runner.rc mismatch"
        print(f"  • Runner.rc: {version} (一致)")
        
    print("[SUCCESS] 全平台版本号 100% 校验通过！")

def main():
    print("========================================")
    print(" CourseWidgets 版本统一同步管理系统")
    print("========================================")
    
    # 检查命令行参数
    if len(sys.argv) >= 3:
        target_version = sys.argv[1].strip()
        target_build = int(sys.argv[2].strip())
        print(f"指定新版本: {target_version} (Build {target_build})")
        write_dart_version(target_version, target_build)
    elif len(sys.argv) == 2:
        target_version = sys.argv[1].strip()
        _, current_build = read_dart_version()
        target_build = current_build + 1
        print(f"指定版本号: {target_version}, 自动累加构建号: {target_build}")
        write_dart_version(target_version, target_build)
    else:
        target_version, target_build = read_dart_version()
        print(f"从 version.dart 读取当前版本: {target_version} (Build {target_build})")
    
    update_pubspec(target_version, target_build)
    update_windows_config(target_version, target_build)
    update_readme_badges(target_version)
    verify_all(target_version, target_build)
    return 0

if __name__ == "__main__":
    sys.exit(main())
