# -*- coding: utf-8 -*-
"""在同一个进程内起假网关线程，然后调用 PHP 客户端发真实 HTTP 请求。

后台进程在命令结束后会被回收，所以不能用「起服务再 curl」的写法，
必须把服务和被测客户端放进同一个进程生命周期里。
"""
import importlib.util
import os
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = 19090

spec = importlib.util.spec_from_file_location("fg", os.path.join(HERE, "fake_gateway.py"))
fg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fg)

server = fg.ThreadingHTTPServer(("127.0.0.1", PORT), fg.Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
time.sleep(0.4)

print("=== 假网关已启动 :%d，开始跑 PHP 客户端 ===\n" % PORT, flush=True)

proc = subprocess.run(
    [os.environ.get("PHP_BIN", "php"), os.path.join(HERE, "php_client.php")],
    capture_output=True,
    timeout=90,
)

out = proc.stdout.decode("utf-8", "replace")
err = proc.stderr.decode("utf-8", "replace")

print(out)
if err.strip():
    print("--- PHP stderr ---")
    print(err[:2000])

print("--- 网关侧记录 ---")
for c in fg._calls:
    print("  %-38s %-22s" % (c["path"][:38], c["result"]))

server.shutdown()
sys.exit(proc.returncode)
