#!/usr/bin/env python3
"""
本地版本提交工具 (Local Git Commit Mechanism)
规则：
1. 仅在本地 git 提交，绝不向任何远程仓库执行 push
2. commit message 格式严格为：v<version>+<buildNumber> (YYYY-MM-DD HH:mm:ss)
3. 自动配置本地 git 用户信息防阻断
"""

import os
import sys
import re
import subprocess
from datetime import datetime

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
VERSION_DART = os.path.join(ROOT_DIR, "lib", "constants", "version.dart")

def read_version():
    with open(VERSION_DART, "r", encoding="utf-8") as f:
        content = f.read()
    v_match = re.search(r"const String appVersion = '([^']+)'", content)
    b_match = re.search(r"const int buildNumber = (\d+)", content)
    if v_match and b_match:
        return v_match.group(1), b_match.group(1)
    return "unknown", "0"

def run_cmd(args, check=True):
    res = subprocess.run(args, cwd=ROOT_DIR, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and res.returncode != 0:
        print(f"Error running {' '.join(args)}:\n{res.stderr}")
    return res

def main():
    version, build = read_version()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    commit_msg = f"v{version}+{build} ({now_str})"

    print(f"==================================================")
    print(f" 本地 Git 版本提交: {commit_msg}")
    print(f"==================================================")

    # 1. 确保本地 git 配置
    run_cmd(["git", "config", "user.name", "CourseWidgets Developer"], check=False)
    run_cmd(["git", "config", "user.email", "dev@coursewidgets.local"], check=False)

    # 2. git add
    print("[1/3] 执行 git add ...")
    run_cmd(["git", "add", "-A"])

    # 3. 检查是否有修改待提交
    status_res = run_cmd(["git", "status", "--porcelain"], check=False)
    if not status_res.stdout.strip():
        print("[INFO] 当前工作区干净，无待提交的改动。")
        return

    # 4. git commit
    print(f"[2/3] 执行 git commit -m \"{commit_msg}\" ...")
    commit_res = run_cmd(["git", "commit", "-m", commit_msg])
    if commit_res.returncode == 0:
        print(f"[SUCCESS] 本地版本提交成功: {commit_msg}")
    else:
        print(f"[WARNING] 提交未完成或已被创建: {commit_res.stdout}")

    # 5. 显示最近一条 log
    print("[3/3] 最近本地提交记录:")
    log_res = run_cmd(["git", "log", "-n", "1", "--oneline"], check=False)
    print(log_res.stdout.strip())
    print("==================================================")

if __name__ == "__main__":
    main()
