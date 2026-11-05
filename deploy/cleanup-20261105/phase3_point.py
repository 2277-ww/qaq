# -*- coding: utf-8 -*-
"""阶段三：移除积分中心（积分商城 / 积分记录 / 积分奖励）。"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

# ---------------- 1. 控制器与视图 ----------------
E.edit(p('app/Http/Home/Controllers/UserConsoleController.php'), [
    ('use App\\Services\\Logic\\User\\Console\\PointGiftRedeemList as PointGiftRedeemListService;\n', ''),
    ('use App\\Services\\Logic\\User\\Console\\PointHistory as PointHistoryService;\n', ''),
    lambda d: d.drop_method('pointHistoryAction'),
    lambda d: d.drop_method('pointGiftRedeemsAction'),
])

E.edit(p('app/Http/Home/Views/user/console/menu.volt'), [
    ("""{% if point_enabled == 1 %}
    <div class="layui-card">
        <div class="layui-card-header">积分中心</div>
        <div class="layui-card-body">
            <ul class="my-menu">
                <li><a href="{{ url({'for':'home.point_gift.list'}) }}">积分商城</a></li>
                <li><a href="{{ url({'for':'home.uc.point_gift_redeems'}) }}">兑换记录</a></li>
                <li><a href="{{ url({'for':'home.uc.point_history'}) }}">积分记录</a></li>
            </ul>
        </div>
    </div>
{% endif %}

""", ''),
    ("{% set point_enabled = setting('point','enabled') %}\n\n", ''),
])

# ---------------- 2. 后台设置与菜单 ----------------
E.edit(p('app/Http/Admin/Controllers/SettingController.php'), [
    lambda d: d.drop_method('pointAction'),
])

E.edit(p('app/Http/Admin/Services/AuthNode.php'), [
    ("""                [
                    'id' => '2-2',
                    'title' => '营销中心',
                    'type' => 'menu',
                    'children' => [
                        [
                            'id' => '2-2-2',
                            'title' => '积分商城',
                            'type' => 'menu',
                            'route' => 'admin.point_gift.list',
                        ],
                    ],
                ],
""", ''),
    ("""                [
                    'id' => '5-3',
                    'title' => '营销配置',
                    'type' => 'menu',
                    'children' => [
                        [
                            'id' => '5-3-1',
                            'title' => '积分奖励',
                            'type' => 'menu',
                            'route' => 'admin.setting.point',
                        ],
                    ],
                ],
""", ''),
])

E.edit(p('app/Repos/Stat.php'), [
    lambda d: d.drop_method('countDailyPointGiftRedeems'),
])

# ---------------- 3. URL 服务 ----------------
E.edit(p('app/Services/Logic/Url/FullH5Url.php'), [
    lambda d: d.drop_plain_method('getPointGiftListUrl'),
    lambda d: d.drop_plain_method('getPointGiftInfoUrl'),
])

E.edit(p('app/Services/Logic/Url/ShareUrl.php'), [
    ("""        } elseif ($type == 'point_gift') {
            $result = $this->getPointGiftUrl($id);
""", ''),
    lambda d: d.drop_plain_method('getPointGiftUrl'),
])

# ---------------- 4. 余额相关 ----------------
E.edit(p('app/Repos/User.php'), [
    ('use App\\Models\\UserBalance as UserBalanceModel;\n', ''),
    lambda d: d.drop_method('findUserBalance'),
])

# ---------------- 5. 删除文件 ----------------
def drop(rel):
    full = p(rel)
    if os.path.exists(full):
        E.remove([full])
    else:
        print('已不存在，跳过：', rel)

for rel in [
    'app/Http/Home/Controllers/PointController.php',
    'app/Http/Home/Controllers/PointGiftController.php',
    'app/Http/Home/Views/point',
    'app/Http/Home/Views/user/console/point_history.volt',
    'app/Http/Home/Views/user/console/point_gift_redeems.volt',
    'app/Http/Home/Views/macros/point_history.volt',
    'app/Http/Home/Views/macros/point_gift.volt',
    'app/Http/Admin/Controllers/PointGiftController.php',
    'app/Http/Admin/Controllers/PointGiftRedeemController.php',
    'app/Http/Admin/Controllers/PointHistoryController.php',
    'app/Http/Admin/Services/PointGift.php',
    'app/Http/Admin/Services/PointGiftRedeem.php',
    'app/Http/Admin/Services/PointHistory.php',
    'app/Http/Admin/Views/point_gift',
    'app/Http/Admin/Views/point_gift_redeem',
    'app/Http/Admin/Views/point_history',
    'app/Http/Admin/Views/setting/point.volt',
    'app/Services/Logic/Point',
    'app/Services/Logic/PointGiftTrait.php',
    'app/Services/Logic/User/Console/PointGiftRedeemList.php',
    'app/Services/Logic/User/Console/PointHistory.php',
    'app/Services/Logic/User/Console/BalanceInfo.php',
    'app/Services/Logic/Notice/External/PointGoodsDeliver.php',
    'app/Services/Logic/Notice/External/DingTalk/PointGiftRedeem.php',
    'app/Caches/PointHotGiftList.php',
    'app/Console/Tasks/PointGiftDeliverTask.php',
    'app/Models/PointGift.php',
    'app/Models/PointGiftRedeem.php',
    'app/Models/PointHistory.php',
    'app/Models/UserBalance.php',
    'app/Repos/PointGift.php',
    'app/Repos/PointGiftRedeem.php',
    'app/Repos/PointHistory.php',
    'app/Validators/PointGift.php',
    'app/Validators/PointGiftRedeem.php',
    'public/static/home/js/point.gift.list.js',
    'public/static/home/js/point.gift.show.js',
    'public/static/home/js/point.rule.js',
]:
    drop(rel)

# ---------------- 6. 清理积分发放调用 ----------------
CALL_RE = re.compile(r'^\s*\$this->handle\w*Point\([^)]*\);\n', re.M)
IMPORT_RE = re.compile(r'^use App\\Services\\Logic\\Point\\History\\[^\n]*\n', re.M)
METHOD_RE = re.compile(r'\n    (?:public|protected|private) function handle\w*Point\([^)]*\)\n    \{\n(?:.*\n)*?    \}\n')

touched = []
for root, dirs, files in os.walk(p('app')):
    for name in files:
        if not name.endswith('.php'):
            continue
        full = os.path.join(root, name)
        rel = os.path.relpath(full, ROOT).replace('\\', '/')
        text = open(full, 'rb').read().decode('utf-8')
        original = text
        newline = '\r\n' if '\r\n' in text else '\n'
        norm = text.replace('\r\n', '\n')
        norm = IMPORT_RE.sub('', norm)
        norm = CALL_RE.sub('', norm)
        norm = METHOD_RE.sub('\n', norm)
        if norm != original.replace('\r\n', '\n'):
            open(full, 'wb').write(norm.replace('\n', newline).encode('utf-8'))
            touched.append(rel)

print('积分调用清理文件数：', len(touched))
for t in touched:
    print('  ', t)
print('阶段三完成')
