# -*- coding: utf-8 -*-
"""阶段三补丁：通知任务、权限节点、账户余额、URL、统计。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

E.edit(p('app/Console/Tasks/NoticeTask.php'), [
    ('use App\\Services\\Logic\\Notice\\External\\PointGoodsDeliver as PointGoodsDeliverNotice;\n', ''),
    ("""                    case TaskModel::TYPE_NOTICE_POINT_GOODS_DELIVER:
                        $this->handlePointGoodsDeliverNotice($task);
                        break;
""", ''),
    ("""                    case TaskModel::TYPE_NOTICE_LIVE_BEGIN:
                        $this->handleLiveBeginNotice($task);
                        break;
""", ''),
    lambda d: d.drop_plain_method('handlePointGoodsDeliverNotice'),
    lambda d: d.drop_plain_method('handleLiveBeginNotice'),
    ('use App\\Services\\Logic\\Notice\\External\\LiveBegin as LiveBeginNotice;\n', ''),
    ("""            TaskModel::TYPE_NOTICE_LIVE_BEGIN,
""", ''),
    ("""            TaskModel::TYPE_NOTICE_POINT_GOODS_DELIVER,
            TaskModel::TYPE_NOTICE_LUCKY_GOODS_DELIVER,
""", ''),
    ("""            TaskModel::TYPE_STAFF_NOTICE_TEACHER_LIVE,
""", ''),
])

E.edit(p('app/Http/Admin/Services/AuthNode.php'), [
    ("""                [
                    'id' => '2-20',
                    'title' => '积分商城',
                    'type' => 'button',
                    'children' => [
                        [
                            'id' => '2-20-1',
                            'title' => '礼品列表',
                            'type' => 'button',
                            'route' => 'admin.point_gift.list',
                        ],
                        [
                            'id' => '2-20-2',
                            'title' => '兑换记录',
                            'type' => 'button',
                            'route' => 'admin.point_gift_redeem.list',
                        ],
                        [
                            'id' => '2-20-3',
                            'title' => '积分记录',
                            'type' => 'button',
                            'route' => 'admin.point_history.list',
                        ],
                        [
                            'id' => '2-20-4',
                            'title' => '添加礼品',
                            'type' => 'button',
                            'route' => 'admin.point_gift.add',
                        ],
                        [
                            'id' => '2-20-5',
                            'title' => '编辑礼品',
                            'type' => 'button',
                            'route' => 'admin.point_gift.edit',
                        ],
                        [
                            'id' => '2-20-6',
                            'title' => '删除礼品',
                            'type' => 'button',
                            'route' => 'admin.point_gift.delete',
                        ],
                    ],
                ],
""", ''),
])

E.edit(p('app/Models/Account.php'), [
    ("""        $userBalance = new UserBalance();
        $userBalance->user_id = $user->id;
        $userBalance->create();
""", ''),
    ('use App\\Models\\UserBalance as UserBalance;\n', ''),
])

E.edit(p('app/Repos/Stat.php'), [
    ('use App\\Models\\PointGiftRedeem as PointGiftRedeemModel;\n', ''),
])

E.edit(p('app/Services/Logic/Url/FullWebUrl.php'), [
    lambda d: d.drop_plain_method('getPointGiftShowUrl'),
])

print('阶段三补丁完成')
