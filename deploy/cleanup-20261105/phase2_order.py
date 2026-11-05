# -*- coding: utf-8 -*-
"""阶段二：移除订单中心 / 交易 / 退款 / 支付。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

# ---------------- 1. 前台控制器 ----------------
E.edit(p('app/Http/Home/Controllers/UserConsoleController.php'), [
    ('use App\\Services\\Logic\\User\\Console\\OrderList as OrderListService;\n', ''),
    ('use App\\Services\\Logic\\User\\Console\\RefundList as RefundListService;\n', ''),
    lambda d: d.drop_method('ordersAction'),
    lambda d: d.drop_method('refundsAction'),
])

E.edit(p('app/Http/Home/Controllers/PublicController.php'), [
    ('use App\\Services\\Pay\\Alipay as AlipayService;\n', ''),
    ('use App\\Services\\Pay\\Wxpay as WxpayService;\n', ''),
    lambda d: d.drop_method('alipayCallbackAction'),
    lambda d: d.drop_method('wxpayCallbackAction'),
    lambda d: d.drop_method('alipayNotifyAction'),
    lambda d: d.drop_method('wxpayNotifyAction'),
])

# ---------------- 2. 用户中心菜单 ----------------
E.edit(p('app/Http/Home/Views/user/console/menu.volt'), [
    ("""
<div class="layui-card">
    <div class="layui-card-header">订单中心</div>
    <div class="layui-card-body">
        <ul class="my-menu">
            <li><a href="{{ url({'for':'home.uc.orders'}) }}">我的订单</a></li>
            <li><a href="{{ url({'for':'home.uc.refunds'}) }}">我的退款</a></li>
        </ul>
    </div>
</div>
""", ''),
])

# ---------------- 3. 课程详情：购买面板与退款期限 ----------------
E.edit(p('app/Http/Home/Views/course/show.volt'), [
    ("            {{ partial('course/show_order') }}\n", ''),
])

E.edit(p('app/Http/Home/Views/course/packages.volt'), [
    ("        {% set order_url = url({'for':'home.order.confirm'},{'item_id':package.id,'item_type':2}) %}\n", ''),
])

E.edit(p('app/Http/Home/Views/course/show_meta.volt'), [
    ("""        {% if course.refund_expiry > 0 %}
            <span class="key">退款期限</span>
            <span class="value">{{ course.refund_expiry }} 天</span>
        {% else %}
            <span class="key">退款期限</span>
            <span class="value">不支持</span>
        {% endif %}
""", ''),
])

# ---------------- 4. 后台：设置、统计、菜单 ----------------
E.edit(p('app/Http/Admin/Controllers/SettingController.php'), [
    lambda d: d.drop_method('payAction'),
])

E.edit(p('app/Http/Admin/Services/Setting.php'), [
    lambda d: d.drop_method('getAlipaySettings'),
    lambda d: d.drop_method('getWxpaySettings'),
])

E.edit(p('app/Http/Admin/Controllers/StatController.php'), [
    lambda d: d.drop_method('hotSalesAction'),
    lambda d: d.drop_method('salesAction'),
    lambda d: d.drop_method('refundsAction'),
])

E.edit(p('app/Caches/SiteTodayStat.php'), [
    ("""        $saleCount = $statRepo->countDailySales($date);
        $refundCount = $statRepo->countDailyRefunds($date);
        $saleAmount = $statRepo->sumDailySales($date);
        $refundAmount = $statRepo->sumDailyRefunds($date);
        $registerCount = $statRepo->countDailyRegisteredUsers($date);
        $pointRedeemCount = $statRepo->countDailyPointGiftRedeems($date);

        return [
            'sale_count' => $saleCount,
            'refund_count' => $refundCount,
            'sale_amount' => $saleAmount,
            'refund_amount' => $refundAmount,
            'register_count' => $registerCount,
            'point_redeem_count' => $pointRedeemCount,
        ];""", """        $registerCount = $statRepo->countDailyRegisteredUsers($date);
        $onlineCount = $statRepo->countDailyOnlineUsers($date);

        return [
            'register_count' => $registerCount,
            'online_count' => $onlineCount,
        ];"""),
])

E.edit(p('app/Http/Admin/Views/index/main_today_stat.volt'), [
    ("""            <div class="layui-col-md4">
                <div class="kg-stat-card">
                    <div class="name">积分兑换</div>
                    <div class="count">{{ today_stat.point_redeem_count }}</div>
                </div>
            </div>
            <div class="layui-col-md4">
                <div class="kg-stat-card">
                    <div class="name">成交订单</div>
                    <div class="count">{{ today_stat.sale_count }}</div>
                </div>
            </div>
            <div class="layui-col-md4">
                <div class="kg-stat-card">
                    <div class="name">成功退款</div>
                    <div class="count">{{ today_stat.refund_count }}</div>
                </div>
            </div>
            <div class="layui-col-md4">
                <div class="kg-stat-card">
                    <div class="name">销售金额</div>
                    <div class="count">{{ '￥%0.2f'|format(today_stat.sale_amount) }}</div>
                </div>
            </div>
            <div class="layui-col-md4">
                <div class="kg-stat-card">
                    <div class="name">退款金额</div>
                    <div class="count">{{ '￥%0.2f'|format(today_stat.refund_amount) }}</div>
                </div>
            </div>""", """            <div class="layui-col-md4">
                <div class="kg-stat-card">
                    <div class="name">活跃学习用户</div>
                    <div class="count">{{ today_stat.online_count }}</div>
                </div>
            </div>"""),
])

E.edit(p('app/Repos/Stat.php'), [
    ('use App\\Models\\Order as OrderModel;\n', ''),
    ('use App\\Models\\OrderStatus as OrderStatusModel;\n', ''),
    ('use App\\Models\\Refund as RefundModel;\n', ''),
    lambda d: d.drop_method('countDailySales'),
    lambda d: d.drop_method('countDailyRefunds'),
    lambda d: d.drop_method('sumDailySales'),
    lambda d: d.drop_method('sumDailyRefunds'),
    lambda d: d.drop_method('findMonthlyOrders'),
])

# ---------------- 5. 通知任务 ----------------
E.edit(p('app/Console/Tasks/NoticeTask.php'), [
    ('use App\\Services\\Logic\\Notice\\External\\OrderFinish as OrderFinishNotice;\n', ''),
    ('use App\\Services\\Logic\\Notice\\External\\RefundFinish as RefundFinishNotice;\n', ''),
    ("""                    case TaskModel::TYPE_NOTICE_ORDER_FINISH:
                        $this->handleOrderFinishNotice($task);
                        break;
                    case TaskModel::TYPE_NOTICE_REFUND_FINISH:
                        $this->handleRefundFinishNotice($task);
                        break;
""", ''),
    lambda d: d.drop_plain_method('handleOrderFinishNotice'),
    lambda d: d.drop_plain_method('handleRefundFinishNotice'),
    ("""            TaskModel::TYPE_NOTICE_ORDER_FINISH,
            TaskModel::TYPE_NOTICE_REFUND_FINISH,
""", ''),
])

# ---------------- 6. 后台菜单 ----------------
E.edit(p('app/Http/Admin/Services/AuthNode.php'), [
    ('        $nodes[] = $this->getFinanceNodes();\n', ''),
    lambda d: d.drop_method('getFinanceNodes'),
    ("""                        [
                            'id' => '2-1-1',
                            'title' => '热卖商品',
                            'type' => 'menu',
                            'route' => 'admin.stat.hot_sales',
                        ],
                        [
                            'id' => '2-1-2',
                            'title' => '成交订单',
                            'type' => 'menu',
                            'route' => 'admin.stat.sales',
                        ],
                        [
                            'id' => '2-1-3',
                            'title' => '售后退款',
                            'type' => 'menu',
                            'route' => 'admin.stat.refunds',
                        ],
""", ''),
    ("""                        [
                            'id' => '5-1-5',
                            'title' => '支付设置',
                            'type' => 'menu',
                            'route' => 'admin.setting.pay',
                        ],
""", ''),
])

# ---------------- 7. 事件注册与调度 ----------------
E.edit(p('config/events.php'), [
    ('use App\\Listeners\\Trade;\n', ''),
    ("    'Trade' => Trade::class,\n", ''),
])

E.edit(p('scheduler.php'), [
    ("""$scheduler->php($script, $bin, ['--task' => 'deliver', '--action' => 'main'])
    ->everyMinute();

""", ''),
    ("""$scheduler->php($script, $bin, ['--task' => 'close_trade', '--action' => 'main'])
    ->everyMinute(13);

""", ''),
    ("""$scheduler->php($script, $bin, ['--task' => 'close_order', '--action' => 'main'])
    ->hourly(3);

""", ''),
    ("""$scheduler->php($script, $bin, ['--task' => 'refund', '--action' => 'main'])
    ->hourly(7);

""", ''),
])

# ---------------- 8. 删除文件 ----------------
def drop(rel):
    full = p(rel)
    if os.path.exists(full):
        E.remove([full])
    else:
        print('已不存在，跳过：', rel)

for rel in [
    'app/Http/Home/Controllers/OrderController.php',
    'app/Http/Home/Controllers/TradeController.php',
    'app/Http/Home/Controllers/RefundController.php',
    'app/Http/Home/Views/order',
    'app/Http/Home/Views/refund',
    'app/Http/Home/Views/course/show_order.volt',
    'app/Http/Home/Views/macros/order.volt',
    'app/Http/Home/Views/macros/refund.volt',
    'app/Http/Home/Views/user/console/orders.volt',
    'app/Http/Home/Views/user/console/refunds.volt',
    'app/Http/Api/Controllers/OrderController.php',
    'app/Http/Api/Controllers/TradeController.php',
    'app/Http/Api/Controllers/RefundController.php',
    'app/Http/Api/Services/Trade.php',
    'app/Http/Admin/Controllers/OrderController.php',
    'app/Http/Admin/Controllers/TradeController.php',
    'app/Http/Admin/Controllers/RefundController.php',
    'app/Http/Admin/Services/Order.php',
    'app/Http/Admin/Services/Trade.php',
    'app/Http/Admin/Services/Refund.php',
    'app/Http/Admin/Services/AlipayTest.php',
    'app/Http/Admin/Services/PayTest.php',
    'app/Http/Admin/Services/WxpayTest.php',
    'app/Http/Admin/Views/order',
    'app/Http/Admin/Views/trade',
    'app/Http/Admin/Views/refund',
    'app/Http/Admin/Views/stat/hot_sales.volt',
    'app/Http/Admin/Views/stat/sales.volt',
    'app/Http/Admin/Views/stat/refunds.volt',
    'app/Http/Admin/Views/setting/pay.volt',
    'app/Http/Admin/Views/setting/pay_alipay.volt',
    'app/Http/Admin/Views/setting/pay_alipay_test.volt',
    'app/Http/Admin/Views/setting/pay_wxpay.volt',
    'app/Http/Admin/Views/setting/pay_wxpay_test.volt',
    'app/Services/Pay.php',
    'app/Services/Pay',
    'app/Services/Refund.php',
    'app/Services/Logic/Order',
    'app/Services/Logic/Refund',
    'app/Services/Logic/Trade',
    'app/Services/Logic/User/Console/OrderList.php',
    'app/Services/Logic/User/Console/RefundList.php',
    'app/Services/Logic/Notice/External/OrderFinish.php',
    'app/Services/Logic/Notice/External/RefundFinish.php',
    'app/Models/Order.php',
    'app/Models/OrderStatus.php',
    'app/Models/Trade.php',
    'app/Models/TradeStatus.php',
    'app/Models/Refund.php',
    'app/Models/RefundStatus.php',
    'app/Repos/Order.php',
    'app/Repos/Trade.php',
    'app/Repos/Refund.php',
    'app/Builders/OrderList.php',
    'app/Builders/RefundList.php',
    'app/Validators/Order.php',
    'app/Validators/Trade.php',
    'app/Validators/Refund.php',
    'app/Console/Tasks/CloseOrderTask.php',
    'app/Console/Tasks/CloseTradeTask.php',
    'app/Console/Tasks/RefundTask.php',
    'app/Console/Tasks/DeliverTask.php',
    'app/Listeners/Trade.php',
    'public/static/home/js/order.info.js',
    'public/static/home/js/order.pay.js',
    'public/static/home/js/refund.info.js',
]:
    drop(rel)

print('阶段二完成')
