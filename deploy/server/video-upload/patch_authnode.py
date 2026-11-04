#!/usr/bin/env python3
# 在 AuthNode.php 的「视频同步」节点后插入「视频上传」菜单节点
# 幂等：已存在则跳过

import os
import shutil
import sys
import time

PATH = '/www/ctc/app/Http/Admin/Services/AuthNode.php'

MARKER = "                [\n                    'id' => '1-6',"

NODE = """                [
                    'id' => '1-9',
                    'title' => '视频上传',
                    'type' => 'menu',
                    'children' => [
                        [
                            'id' => '1-9-1',
                            'title' => '上传演示视频',
                            'type' => 'menu',
                            'route' => 'admin.video_upload.index',
                        ],
                        [
                            'id' => '1-9-2',
                            'title' => '媒体库',
                            'type' => 'menu',
                            'route' => 'admin.video_upload.list',
                        ],
                        [
                            'id' => '1-9-3',
                            'title' => '删除文件',
                            'type' => 'button',
                            'route' => 'admin.video_upload.delete',
                        ],
                    ],
                ],
"""


def main():
    if not os.path.isfile(PATH):
        print('FAIL: %s not found' % PATH)
        return 1

    with open(PATH, encoding='utf-8') as fp:
        content = fp.read()

    if "'admin.video_upload.index'" in content:
        print('SKIP: menu node already present')
        return 0

    idx = content.find(MARKER)

    if idx < 0:
        print('FAIL: anchor not found, AuthNode.php layout changed')
        return 1

    backup = PATH + '.bak.' + time.strftime('%Y%m%d%H%M%S')
    shutil.copy(PATH, backup)

    updated = content[:idx] + NODE + content[idx:]

    with open(PATH, 'w', encoding='utf-8') as fp:
        fp.write(updated)

    print('OK: inserted at offset %d, backup=%s' % (idx, backup))
    return 0


if __name__ == '__main__':
    sys.exit(main())
