#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CourseWidgets Release 收集与整理工具 (collect_release.py)
用于自动将各平台构建产物收集整理至根目录 release/ 文件夹中，
提供统一命名、SHA256 校验和以及版本元数据清单。
"""

import os
import sys
import re
import shutil
import hashlib
import json
from datetime import datetime

# Windows 控制台编码安全
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
RELEASE_DIR = os.path.join(ROOT_DIR, 'release')
VERSION_DART = os.path.join(ROOT_DIR, 'lib', 'constants', 'version.dart')

def get_app_version():
    version = "2.7.0"
    build = "10008034"
    if os.path.exists(VERSION_DART):
        with open(VERSION_DART, 'r', encoding='utf-8') as f:
            content = f.read()
            m_ver = re.search(r"appVersion\s*=\s*'([^']+)'", content)
            m_build = re.search(r"buildNumber\s*=\s*(\d+)", content)
            if m_ver:
                version = m_ver.group(1)
            if m_build:
                build = m_build.group(1)
    return version, build

def calculate_sha256(filepath):
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def format_size(bytes_size):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.2f} TB"

def collect_android_apks(version, build):
    apk_dir = os.path.join(ROOT_DIR, 'build', 'app', 'outputs', 'flutter-apk')
    if not os.path.exists(apk_dir):
        print(f"[提示] 未找到 Android 构建输出目录: {apk_dir}")
        return []

    collected = []
    now = datetime.now().timestamp()
    
    arm64_src = os.path.join(apk_dir, 'app-arm64-v8a-release.apk')
    universal_src = os.path.join(apk_dir, 'app-release.apk')
    
    universal_fresh = os.path.exists(universal_src) and (now - os.path.getmtime(universal_src)) < 7200
    arm64_fresh = os.path.exists(arm64_src) and (now - os.path.getmtime(arm64_src)) < 7200
    
    effective_arm64_src = None
    if arm64_fresh:
        effective_arm64_src = arm64_src
    elif universal_fresh:
        effective_arm64_src = universal_src

    targets = []
    if effective_arm64_src:
        targets.append((effective_arm64_src, f"CourseWidgets-v{version}-android-arm64-v8a.apk"))
    if universal_fresh:
        targets.append((universal_src, f"CourseWidgets-v{version}-android-universal.apk"))
        
    for src_path, target_name in targets:
        dst_path = os.path.join(RELEASE_DIR, target_name)
        shutil.copy2(src_path, dst_path)
        
        size = os.path.getsize(dst_path)
        sha = calculate_sha256(dst_path)
        collected.append({
            'platform': 'Android',
            'filename': target_name,
            'source': os.path.basename(src_path),
            'path': dst_path,
            'size': size,
            'size_formatted': format_size(size),
            'sha256': sha,
            'updated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        })
        print(f"[OK] 已收集 Android APK: {target_name} ({format_size(size)})")

    return collected

def collect_windows_release(version, build):
    win_dir = os.path.join(ROOT_DIR, 'build', 'windows', 'x64', 'runner', 'Release')
    if not os.path.exists(win_dir):
        return []

    # 检查是否存在 CourseWidgets.exe 或任意主程序 exe
    exe_found = False
    for fname in os.listdir(win_dir):
        if fname.lower().endswith('.exe') and not fname.lower().startswith('unit'):
            exe_found = True
            break

    if not exe_found:
        return []

    # 仅在 Windows 构建产物在近期（2小时内）有更新时打包收集
    now = datetime.now().timestamp()
    if (now - os.path.getmtime(win_dir)) > 7200:
        return []

    collected = []
    zip_name = f"CourseWidgets-v{version}-windows-x64.zip"
    zip_base = os.path.join(RELEASE_DIR, f"CourseWidgets-v{version}-windows-x64")
    
    # 压缩整个 Release 目录
    shutil.make_archive(zip_base, 'zip', win_dir)
    full_zip = zip_base + '.zip'
    
    size = os.path.getsize(full_zip)
    sha = calculate_sha256(full_zip)
    collected.append({
        'platform': 'Windows',
        'filename': zip_name,
        'source': 'build/windows/x64/runner/Release',
        'path': full_zip,
        'size': size,
        'size_formatted': format_size(size),
        'sha256': sha,
        'updated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    })
    print(f"[OK] 已打包收集 Windows 客户端: {zip_name} ({format_size(size)})")
    return collected

def main():
    print("=" * 60)
    print(" CourseWidgets Release 收集与整理工具")
    print("=" * 60)

    version, build = get_app_version()
    print(f"目标版本: v{version} (Build {build})")

    os.makedirs(RELEASE_DIR, exist_ok=True)

    all_artifacts = []
    all_artifacts.extend(collect_android_apks(version, build))
    all_artifacts.extend(collect_windows_release(version, build))

    if not all_artifacts:
        print("\n[警告] 未在 build/ 目录中检测到任何 Release 构建产物。")
        return 1

    manifest = {
        'version': version,
        'buildNumber': int(build),
        'collectedAt': datetime.now().isoformat(),
        'artifacts': all_artifacts
    }
    manifest_path = os.path.join(RELEASE_DIR, 'RELEASE_MANIFEST.json')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    readme_path = os.path.join(RELEASE_DIR, 'README.md')
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(f"# CourseWidgets v{version} (Build {build}) Release 产物发布归档\n\n")
        f.write(f"> **生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  \n")
        f.write(f"> **版本号**: `{version}` (`{build}`)  \n\n")
        f.write("## 产物下载与校验列表\n\n")
        f.write("| 平台 | 文件名 | 体积 | SHA256 校验和 |\n")
        f.write("| :--- | :--- | :--- | :--- |\n")
        for item in all_artifacts:
            f.write(f"| {item['platform']} | `{item['filename']}` | {item['size_formatted']} | `{item['sha256'][:16]}...{item['sha256'][-8:]}` |\n")
        f.write("\n## 完整校验和 (SHA-256)\n\n```text\n")
        for item in all_artifacts:
            f.write(f"{item['sha256']}  {item['filename']}\n")
        f.write("```\n")

    print("\n" + "=" * 60)
    print(f"[SUCCESS] 成功整理并输出至 release/ 目录:")
    for item in all_artifacts:
        print(f"  • {item['filename']} ({item['size_formatted']})")
    print(f"  • 清单文件: release/RELEASE_MANIFEST.json")
    print(f"  • 说明文档: release/README.md")
    print("=" * 60)
    return 0

if __name__ == '__main__':
    sys.exit(main())
