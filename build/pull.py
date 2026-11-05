#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""从服务器拉取单个文件（补充 remote.py 缺失的取回能力）。

用法:
  python build/pull.py 远程路径 本地路径
"""
import os
import sys
import paramiko

HOST = os.environ.get("CTC_HOST", "8.138.34.151")
USER = os.environ.get("CTC_USER", "root")
PWD = os.environ.get("CTC_PWD", "")
KEY = os.environ.get("CTC_KEY", os.path.expanduser("~/.ssh/ctc_ed25519"))


def client():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    kw = dict(port=22, username=USER, timeout=25,
              banner_timeout=30, auth_timeout=30,
              look_for_keys=False, allow_agent=False)
    if os.path.exists(KEY):
        kw["key_filename"] = KEY
    elif PWD:
        kw["password"] = PWD
    else:
        raise SystemExit("缺少凭据：请设置 CTC_PWD 或提供私钥")
    c.connect(HOST, **kw)
    return c


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    remote, local = sys.argv[1], sys.argv[2]

    c = client()
    try:
        # cat 走 stdio，读二进制后再落盘，避免 SFTP 不可用的问题
        stdin, stdout, stderr = c.exec_command("cat %s" % remote, timeout=300)
        data = stdout.read()
        err = stderr.read().decode("utf-8", "replace")
        code = stdout.channel.recv_exit_status()
    finally:
        c.close()

    if code != 0:
        raise SystemExit("读取失败 exit=%d %s" % (code, err[:300]))

    os.makedirs(os.path.dirname(os.path.abspath(local)), exist_ok=True)
    with open(local, "wb") as f:
        f.write(data)
    print("saved %s (%d bytes)" % (local, len(data)))


if __name__ == "__main__":
    main()
