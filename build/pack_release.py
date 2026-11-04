#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 C:\\ctc\\www 上运行中的改造版打包成交付物。

产出（dist/ 目录）：
  ctc-selflearn-src-<ver>.zip      源码包：代码 + 依赖清单，不含 vendor / 演示视频
  ctc-selflearn-runtime-<ver>.zip  可运行包：额外含 vendor，解压即可离线启动
  manifest-src.txt / manifest-runtime.txt  文件级 SHA256 清单
"""

import hashlib
import os
import re
import shutil
import sys
import zipfile
from pathlib import Path

SRC = Path(r"C:\ctc\www")
OUT = Path(r"C:\Users\paradox\Desktop\自学·平台\dist")
VER = "20261104"
ROOT = f"ctc-selflearn-{VER}"

# 目录级排除（匹配相对路径前缀）
EXCLUDE_DIR_PREFIXES = (
    "vendor",
    "public/static/vod",
    "storage/cache",
    "storage/log",
    "storage/tmp",
    "_removed_auth",
    "_removed_vip",
    ".git",
)

# 文件级排除
EXCLUDE_FILES = {
    "config/config.php",      # 本地运行配置，改由 config.example.php 提供
    ".gitignore",
}

# vendor 只在运行包里出现
VENDOR_PREFIX = "vendor"


def should_skip(rel: str, include_vendor: bool) -> bool:
    if rel.startswith(VENDOR_PREFIX + "/") or rel == VENDOR_PREFIX:
        return not include_vendor
    for p in EXCLUDE_DIR_PREFIXES:
        if rel == p or rel.startswith(p + "/"):
            return True
    if rel in EXCLUDE_FILES:
        return True
    if rel.endswith((".pyc", ".log")) and rel.startswith("storage/"):
        return True
    return False


def iter_files(include_vendor: bool):
    for dirpath, dirnames, filenames in os.walk(SRC):
        rel_dir = Path(dirpath).relative_to(SRC).as_posix()
        rel_dir = "" if rel_dir == "." else rel_dir
        dirnames.sort()
        for name in sorted(filenames):
            rel = f"{rel_dir}/{name}" if rel_dir else name
            if should_skip(rel, include_vendor):
                continue
            yield rel, Path(dirpath) / name


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def config_example() -> str:
    text = (SRC / "config" / "config.php").read_text(encoding="utf-8")
    # 去掉本地密钥与本地数据库口令，改成占位符
    text = re.sub(r"(\$config\['key'\] = ')[^']*(';)",
                  r"\1PUT-YOUR-APP-KEY-HERE\2", text)
    text = text.replace("$config['db']['username'] = 'root';",
                        "$config['db']['username'] = 'ctc';")
    text = text.replace("$config['db']['password'] = '';",
                        "$config['db']['password'] = 'PUT-YOUR-DB-PASSWORD';")
    text = text.replace("$config['env'] = 'dev';", "$config['env'] = 'pro';")
    return text


DEPLOY_README = """\
# 自学平台（基于酷瓜云课堂改造）交付包

版本：__VER__
来源：酷瓜云课堂 CTC 1.8.3（GPL-2.0，https://gitee.com/koogua/course-tencent-cloud）
本包内容：__DESC__

## 1. 运行环境（硬性要求）

| 组件 | 版本 | 说明 |
|---|---|---|
| PHP | 7.3.x (NTS, VC15, x64) | 必须装 ext-phalcon 3.4、redis、pdo_mysql、gd、fileinfo、json、igbinary |
| Phalcon | 3.4.5 | C 扩展，不能用 Composer 安装 |
| MySQL | 5.7 | 库名 ctc，字符集 utf8mb4 |
| Redis | 5.x | 会话、缓存、队列 |
| Composer | 2.x | 仅源码包首次安装依赖时需要 |

## 2. 目录约定

    app/            业务代码（MVC 三套模块：Home 前台 / Admin 后台 / Api）
    bootstrap/      引导与内核（Kernel.php、HttpKernel.php）
    config/         运行配置（config.php 由 config.example.php 复制而来）
    db/migrations/  Phinx 数据库迁移
    public/         站点根目录（唯一对外暴露的目录）
    public/index.php  入口文件
    router.php      PHP 内置服务器路由重写（仅本地调试用）
    storage/        缓存、日志、临时文件（需可写）
    vendor/         Composer 依赖（仅可运行包内有）
    websocket/      GatewayWorker 长连接服务
    tools/          演示数据与片源同步脚本

## 3. 启动（本地/单机）

1. 建库并执行迁移：

       php console.php migrate           # 或 vendor/bin/phinx migrate -c phinx.php

2. 生成配置：

       cp config/config.example.php config/config.php
       # 修改 db / redis / key

3. 启动站点（工作目录必须是 public）：

       cd public
       php -S 127.0.0.1:8000 ..\\router.php

4. 需要长连接时另起进程：

       php websocket/start_register.php
       php websocket/start_gateway.php
       php websocket/start_businessworker.php

## 4. 生产部署要点（Nginx）

    root /path/to/public;
    location / {
        try_files $uri $uri/ /index.php?_url=$uri&$args;
    }
    location ~ \\.php$ {
        fastcgi_pass 127.0.0.1:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

`public/static/vod` 未打进包（演示视频 1.3 GB），生产环境应接入对象存储。

## 5. 关于 Vercel

本包**不能**直接部署到 Vercel：Vercel 无 PHP 7.3 + Phalcon C 扩展运行时，
也没有可写的本地磁盘、MySQL 与 Redis，且 GatewayWorker 需要常驻进程。
详见交付报告《源码核查与 Vercel 部署可行性》。
"""


def build(include_vendor: bool):
    tag = "runtime" if include_vendor else "src"
    desc = "完整代码 + Composer 依赖 vendor（可直接离线启动）" if include_vendor \
        else "完整业务代码 + composer.json/lock（vendor 需自行 composer install）"
    zip_path = OUT / f"ctc-selflearn-{tag}-{VER}.zip"
    manifest_path = OUT / f"manifest-{tag}.txt"

    files = list(iter_files(include_vendor))
    total = 0
    lines = []
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for rel, path in files:
            arc = f"{ROOT}/{rel}"
            zf.write(path, arc)
            size = path.stat().st_size
            total += size
            lines.append(f"{sha256(path)}  {size:>10}  {rel}")

        # 派生产物
        zf.writestr(f"{ROOT}/config/config.example.php", config_example())
        zf.writestr(f"{ROOT}/README_DEPLOY.md", DEPLOY_README.replace("__VER__", VER).replace("__DESC__", desc))
        for sub in ("storage/cache/annotations", "storage/cache/metadata",
                    "storage/cache/purifier", "storage/cache/volt",
                    "storage/log", "storage/tmp"):
            zf.writestr(f"{ROOT}/{sub}/.gitkeep", "")
        zf.writestr(f"{ROOT}/PACKAGE_INFO.txt", (
            f"package: ctc-selflearn-{tag}-{VER}\n"
            f"files: {len(files)}\n"
            f"raw bytes: {total}\n"
            f"note: public/static/vod 与 _removed_* 未包含\n"
        ))

    manifest_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"[{tag}] files={len(files)} raw={total/1048576:.1f}MB "
          f"zip={zip_path.stat().st_size/1048576:.1f}MB -> {zip_path}")
    return zip_path


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    if which in ("src", "both"):
        build(False)
    if which in ("runtime", "both"):
        build(True)
