#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""远程执行助手：paramiko 封装，供部署脚本复用。

用法:
  python build/remote.py exec "命令"        # 执行并输出
  python build/remote.py put 本地 远程       # 上传
  python build/remote.py putdir 本地目录 远程目录
"""
import sys
import os
import paramiko

HOST = os.environ.get("CTC_HOST", "8.138.34.151")
USER = os.environ.get("CTC_USER", "root")

# 凭据只从环境变量或本地密钥读取，禁止硬编码进仓库
PWD = os.environ.get("CTC_PWD", "")
KEY = os.environ.get("CTC_KEY", os.path.expanduser("~/.ssh/ctc_ed25519"))


def client():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = dict(port=22, username=USER,
              timeout=25, banner_timeout=30, auth_timeout=30,
              look_for_keys=False, allow_agent=False)

    if os.path.exists(KEY):
        kw["key_filename"] = KEY
    elif PWD:
        kw["password"] = PWD
    else:
        raise SystemExit(
            "缺少凭据：请设置环境变量 CTC_PWD，"
            "或把私钥放到 %s（可用 CTC_KEY 指定路径）" % KEY
        )

    c.connect(HOST, **kw)
    return c


def run(cmd, timeout=600, quiet=False):
    c = client()
    try:
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=False)
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
        code = stdout.channel.recv_exit_status()
    finally:
        c.close()
    if not quiet:
        if out:
            sys.stdout.write(out)
        if err:
            sys.stderr.write(err)
    return code, out, err


def put(local, remote):
    """通过 cat 重定向写入远端文件（不依赖 SFTP）。"""
    import shlex
    with open(local, "rb") as f:
        data = f.read()
    c = client()
    try:
        stdin, stdout, stderr = c.exec_command(
            "cat > %s" % shlex.quote(remote), timeout=600)
        stdin.write(data)
        stdin.flush()
        stdin.channel.shutdown_write()
        code = stdout.channel.recv_exit_status()
        err = stderr.read().decode("utf-8", "replace")
        if code != 0:
            raise IOError("remote write failed, exit=%d, stderr=%s" % (code, err[:300]))
    finally:
        c.close()


def putdir(local_dir, remote_dir):
    c = client()
    try:
        sftp = c.open_sftp()

        def walk(local, remote):
            try:
                sftp.mkdir(remote)
            except IOError:
                pass
            for name in os.listdir(local):
                lp = os.path.join(local, name)
                rp = remote + "/" + name
                if os.path.isdir(lp):
                    walk(lp, rp)
                else:
                    sftp.put(lp, rp)

        walk(local_dir, remote_dir)
        sftp.close()
    finally:
        c.close()


if __name__ == "__main__":
    action = sys.argv[1]
    if action == "exec":
        code, out, err = run(sys.argv[2])
        sys.exit(code)
    elif action == "put":
        put(sys.argv[2], sys.argv[3])
        print("uploaded", sys.argv[2])
    elif action == "putdir":
        putdir(sys.argv[2], sys.argv[3])
        print("uploaded dir", sys.argv[2])
