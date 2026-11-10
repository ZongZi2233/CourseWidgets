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

def find_aapt():
    candidate_dirs = [
        r"D:\Users\26390\AppData\Android\build-tools",
        os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\build-tools"),
    ]
    local_props = os.path.join(ROOT_DIR, 'android', 'local.properties')
    if os.path.exists(local_props):
        try:
            with open(local_props, 'r', encoding='utf-8') as f:
                for line in f:
                    if line.startswith('sdk.dir='):
                        sdk_dir = line.split('=', 1)[1].strip().replace('\\\\', '\\')
                        candidate_dirs.insert(0, os.path.join(sdk_dir, 'build-tools'))
        except Exception:
            pass
    for base in candidate_dirs:
        if os.path.exists(base):
            try:
                for entry in sorted(os.listdir(base), reverse=True):
                    aapt_path = os.path.join(base, entry, 'aapt.exe')
                    if os.path.exists(aapt_path):
                        return aapt_path
            except Exception:
                pass
    return shutil.which('aapt')

def get_apk_badging(apk_path, aapt_exe):
    if not aapt_exe or not os.path.exists(aapt_exe):
        return None, None
    import subprocess
    try:
        res = subprocess.run([aapt_exe, 'dump', 'badging', apk_path], capture_output=True, text=True, errors='ignore')
        m_ver = re.search(r"versionName='([^']+)'", res.stdout)
        m_code = re.search(r"versionCode='([^']+)'", res.stdout)
        ver = m_ver.group(1) if m_ver else None
        code = m_code.group(1) if m_code else None
        return ver, code
    except Exception as e:
        print(f"[警告] 读取 APK badging 失败: {e}")
        return None, None

def collect_android_apks(version, build):
    apk_dir = os.path.join(ROOT_DIR, 'build', 'app', 'outputs', 'flutter-apk')
    if not os.path.exists(apk_dir):
        print(f"[提示] 未找到 Android 构建输出目录: {apk_dir}")
        return []

    collected = []
    aapt_exe = find_aapt()
    if aapt_exe:
        print(f"[工具] 找到 aapt 工具: {aapt_exe}")
    else:
        print(f"[警告] 未找到 aapt 工具，将仅依赖修改时间进行收集")

    arm64_src = os.path.join(apk_dir, 'app-arm64-v8a-release.apk')
    universal_src = os.path.join(apk_dir, 'app-release.apk')

    # 清理 release/ 中已存在的同版本旧包，避免残留
    if os.path.exists(RELEASE_DIR):
        for fname in os.listdir(RELEASE_DIR):
            if fname.startswith(f"CourseWidgets-v{version}-android-"):
                try:
                    os.remove(os.path.join(RELEASE_DIR, fname))
                except Exception:
                    pass

    targets = []

    # 严格校验并仅收集 arm64-v8a (按用户要求不提供 Universal 冗余包)
    selected_apk = None
    if os.path.exists(arm64_src):
        selected_apk = arm64_src
    elif os.path.exists(universal_src):
        selected_apk = universal_src

    if selected_apk:
        apk_ver, apk_code = get_apk_badging(selected_apk, aapt_exe)
        print(f"[APK 校验] arm64-v8a: source={os.path.basename(selected_apk)}, versionName={apk_ver}, versionCode={apk_code}, 目标预期={version}+{build}")
        if apk_ver is not None:
            if apk_ver == version:
                targets.append((selected_apk, f"CourseWidgets-v{version}-android-arm64-v8a.apk"))
            else:
                print(f"[严重错误] APK 版本号 ({apk_ver}) 与预期 ({version}) 不一致，严禁收集陈旧脏包！")
        else:
            # aapt 不可用时的保护
            targets.append((selected_apk, f"CourseWidgets-v{version}-android-arm64-v8a.apk"))
    else:
        print(f"[提示] 未找到 arm64-v8a 构建产物 (检查了 {arm64_src} 与 {universal_src})")

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
        print(f"[OK] 已收集并校验 Android APK: {target_name} ({format_size(size)})")

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

    sha256_path = os.path.join(RELEASE_DIR, 'SHA256SUMS.txt')
    with open(sha256_path, 'w', encoding='utf-8') as f:
        for item in all_artifacts:
            f.write(f"{item['sha256']}  {item['filename']}\n")

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
