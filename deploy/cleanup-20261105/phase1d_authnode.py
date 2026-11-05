# -*- coding: utf-8 -*-
"""阶段一：后台菜单去掉「直播设置」节点。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

E.edit(p('app/Http/Admin/Services/AuthNode.php'), [
    ("""                        [
                            'id' => '5-2-6',
                            'title' => '直播设置',
                            'type' => 'menu',
                            'route' => 'admin.setting.live',
                        ],
""", ''),
])

print('后台菜单已去掉直播设置')
