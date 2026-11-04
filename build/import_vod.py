#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把本地演示视频批量导入服务器媒体目录。

保持原有层级：本地 public/static/vod/<slug>/<file>.mp4
            -> /www/media/vod/<slug>/<file>.mp4
这样数据库里 /static/vod/ 的路径只需换前缀即可，不用改文件名。
"""
import os
import shlex
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remote

SRC = r"C:\ctc\www\public\static\vod"
DST = "/www/media/vod"

EXT = ('.mp4', '.webm', '.m4v')


def main():
    files = []
    for root, _dirs, names in os.walk(SRC):
        for name in names:
            if name.lower().endswith(EXT):
                files.append(os.path.join(root, name))

    if not files:
        print("no media found under", SRC)
        return 1

    files.sort(key=lambda p: os.path.getsize(p))

    total_bytes = sum(os.path.getsize(f) for f in files)
    print("files=%d total=%.1f MB" % (len(files), total_bytes / 1048576.0))

    conn = remote.client()

    try:
        _exec(conn, "mkdir -p %s" % shlex.quote(DST))

        done_bytes = 0
        started = time.time()

        for index, path in enumerate(files, 1):
            rel = os.path.relpath(path, SRC).replace("\\", "/")
            target = DST + "/" + rel
            size = os.path.getsize(path)

            _exec(conn, "mkdir -p %s" % shlex.quote(os.path.dirname(target)))

            with open(path, "rb") as fp:
                payload = fp.read()

            code = _write(conn, target, payload)

            if code != 0:
                print("FAIL %s (exit=%d)" % (rel, code))
                return 1

            done_bytes += size
            elapsed = max(time.time() - started, 0.001)
            speed = done_bytes / elapsed / 1048576.0
            print("[%2d/%2d] %-44s %6.1f MB  总进度 %.0f%%  %.2f MB/s" % (
                index, len(files), rel, size / 1048576.0,
                done_bytes * 100.0 / total_bytes, speed))
            sys.stdout.flush()

        elapsed = time.time() - started
        print("DONE %d files, %.1f MB in %.1f s" % (
            len(files), total_bytes / 1048576.0, elapsed))

    finally:
        conn.close()

    return 0


def _exec(conn, command):
    stdin, stdout, stderr = conn.exec_command(command, timeout=120)
    stdout.channel.recv_exit_status()
    stdin.close()
    stdout.close()
    stderr.close()


def _write(conn, target, payload):
    stdin, stdout, stderr = conn.exec_command(
        "cat > %s" % shlex.quote(target), timeout=900)
    stdin.write(payload)
    stdin.flush()
    stdin.channel.shutdown_write()
    code = stdout.channel.recv_exit_status()
    stdin.close()
    stdout.close()
    stderr.close()
    return code


if __name__ == '__main__':
    sys.exit(main())
