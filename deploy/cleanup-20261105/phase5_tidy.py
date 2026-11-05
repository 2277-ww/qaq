# -*- coding: utf-8 -*-
"""阶段五：收尾清理（短信/公众号模板、权益宏、营销表单、配置项）。"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
MYSQL = r'C:/ctc/mysql/bin/mysql.exe'


def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))


# 1. 加入来源枚举：去掉「积分」
for rel in ['app/Http/Home/Views/macros/ownership.volt', 'app/Http/Admin/Views/macros/ownership.volt']:
    E.edit(p(rel), [
        ("""    {% elseif value == 5 %}
        积分
""", ''),
    ])

# 2. 短信模板：去掉购买成功 / 商品发货 / 退款成功
E.edit(p('app/Http/Admin/Views/setting/sms.volt'), [
    ("""            <tr>
                <td>购买成功通知</td>
                <td>
                    <input type="radio" name="template[order_finish][enabled]" value="1" title="是" {% if template.order_finish.enabled == "1" %}checked="checked"{% endif %}>
                    <input type="radio" name="template[order_finish][enabled]" value="0" title="否" {% if template.order_finish.enabled == "0" %}checked="checked"{% endif %}>
                </td>
                <td><input class="layui-input" type="text" name="template[order_finish][id]" value="{{ template.order_finish.id }}" lay-verify="required"></td>
                <td><input id="tc-order-finish" class="layui-input" type="text" value="下单成功，商品名称：{1}，订单序号：{2}，订单金额：{3}元" readonly="readonly"></td>
                <td><span class="kg-copy layui-btn" data-clipboard-target="#tc-order-finish">复制</span></td>
            </tr>
            <tr>
                <td>商品发货通知</td>
                <td>
                    <input type="radio" name="template[goods_deliver][enabled]" value="1" title="是" {% if template.goods_deliver.enabled == "1" %}checked="checked"{% endif %}>
                    <input type="radio" name="template[goods_deliver][enabled]" value="0" title="否" {% if template.goods_deliver.enabled == "0" %}checked="checked"{% endif %}>
                </td>
                <td><input class="layui-input" type="text" name="template[goods_deliver][id]" value="{{ template.goods_deliver.id }}" lay-verify="required"></td>
                <td><input id="tc-goods-deliver" class="layui-input" type="text" value="发货成功，商品名称：{1}，订单序号：{2}，发货时间：{3}，请注意查收。" readonly="readonly"></td>
                <td><span class="kg-copy layui-btn" data-clipboard-target="#tc-goods-deliver">复制</span></td>
            </tr>
            <tr>
                <td>退款成功通知</td>
                <td>
                    <input type="radio" name="template[refund_finish][enabled]" value="1" title="是" {% if template.refund_finish.enabled == "1" %}checked="checked"{% endif %}>
                    <input type="radio" name="template[refund_finish][enabled]" value="0" title="否" {% if template.refund_finish.enabled == "0" %}checked="checked"{% endif %}>
                </td>
                <td><input class="layui-input" type="text" name="template[refund_finish][id]" value="{{ template.refund_finish.id }}" lay-verify="required"></td>
                <td><input id="tc-refund-finish" class="layui-input" type="text" value="退款成功，商品名称：{1}，退款序号：{2}，退款金额：{3}元" readonly="readonly"></td>
                <td><span class="kg-copy layui-btn" data-clipboard-target="#tc-refund-finish">复制</span></td>
            </tr>
""", ''),
])

# 3. 公众号模板：去掉购买 / 发货 / 退款；注释块里只保留咨询回复
E.edit(p('app/Http/Admin/Views/setting/wechat_oa_notice.volt'), [
    ("""        <tr>
            <td>购买成功通知</td>
            <td>
                <input type="radio" name="notice_template[order_finish][enabled]" value="1" title="是" {% if notice_template.order_finish.enabled == "1" %}checked="checked"{% endif %}>
                <input type="radio" name="notice_template[order_finish][enabled]" value="0" title="否" {% if notice_template.order_finish.enabled == "0" %}checked="checked"{% endif %}>
            </td>
            <td><input class="layui-input" type="text" name="notice_template[order_finish][id]" value="{{ notice_template.order_finish.id }}" lay-verify="required"></td>
        </tr>
        <tr>
            <td>商品发货通知</td>
            <td>
                <input type="radio" name="notice_template[goods_deliver][enabled]" value="1" title="是" {% if notice_template.goods_deliver.enabled == "1" %}checked="checked"{% endif %}>
                <input type="radio" name="notice_template[goods_deliver][enabled]" value="0" title="否" {% if notice_template.goods_deliver.enabled == "0" %}checked="checked"{% endif %}>
            </td>
            <td><input class="layui-input" type="text" name="notice_template[goods_deliver][id]" value="{{ notice_template.goods_deliver.id }}" lay-verify="required"></td>
        </tr>
        <tr>
            <td>退款成功通知</td>
            <td>
                <input type="radio" name="notice_template[refund_finish][enabled]" value="1" title="是" {% if notice_template.refund_finish.enabled == "1" %}checked="checked"{% endif %}>
                <input type="radio" name="notice_template[refund_finish][enabled]" value="0" title="否" {% if notice_template.refund_finish.enabled == "0" %}checked="checked"{% endif %}>
            </td>
            <td><input class="layui-input" type="text" name="notice_template[refund_finish][id]" value="{{ notice_template.refund_finish.id }}" lay-verify="required"></td>
        </tr>
        <!--
        <tr>
            <td>课程直播提醒</td>
            <td>
                <input type="radio" name="notice_template[live_begin][enabled]" value="1" title="是" {% if notice_template.live_begin.enabled == "1" %}checked="checked"{% endif %}>
                <input type="radio" name="notice_template[live_begin][enabled]" value="0" title="否" {% if notice_template.live_begin.enabled == "0" %}checked="checked"{% endif %}>
            </td>
            <td><input class="layui-input" type="text" name="notice_template[live_begin][id]" value="{{ notice_template.live_begin.id }}" lay-verify="required"></td>
        </tr>
        <tr>
""", """        <tr>
"""),
    ("""        </tr>
        -->
        </tbody>""", """        </tr>
        </tbody>"""),
])

# 4. 课程营销设置：去掉退款期限
E.edit(p('app/Http/Admin/Views/course/edit_sale.volt'), [
    ("""        <div class="layui-form-item">
            <label class="layui-form-label">退款期限</label>
            <div class="layui-input-block">
                {% for key,value in refund_expiry_options %}
                    <input type="radio" name="refund_expiry" title="{{ value }}" value="{{ key }}" {% if key == course.refund_expiry %}checked="checked"{% endif %}>
                {% endfor %}
            </div>
        </div>
""", ''),
])

# 5. 数据库：清掉直播 / 支付 / 积分配置
sql = "DELETE FROM kg_setting WHERE section LIKE 'live.%' OR section LIKE 'pay.%' OR section = 'point';"
proc = subprocess.run([MYSQL, '-uroot', '--default-character-set=utf8mb4', 'ctc', '-e', sql],
                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
print('配置清理返回码：', proc.returncode)
if proc.stderr.strip():
    print(proc.stderr.decode('utf-8', 'replace'))

print('阶段五完成')
