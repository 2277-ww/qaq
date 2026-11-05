# -*- coding: utf-8 -*-
"""阶段一残余：后台列表类型宏、短信模板、教师端脚本。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

E.edit(p('app/Http/Admin/Views/macros/course.volt'), [
    ("""    {% if value == 1 %}
        点播
    {% elseif value == 2 %}
        直播
    {% elseif value == 3 %}
        图文
    {% elseif value == 4 %}
        面授
    {% else %}
        N/A
    {% endif %}""", """    {% if value == 1 %}
        点播
    {% elseif value == 3 %}
        图文
    {% else %}
        N/A
    {% endif %}"""),
])

E.edit(p('app/Http/Admin/Views/setting/sms.volt'), [
    ("""            <tr>
                <td>课程直播提醒</td>
                <td>
                    <input type="radio" name="template[live_begin][enabled]" value="1" title="是" {% if template.live_begin.enabled == "1" %}checked="checked"{% endif %}>
                    <input type="radio" name="template[live_begin][enabled]" value="0" title="否" {% if template.live_begin.enabled == "0" %}checked="checked"{% endif %}>
                </td>
                <td><input class="layui-input" type="text" name="template[live_begin][id]" value="{{ template.live_begin.id }}" lay-verify="required"></td>
                <td><input id="tc-live-begin" class="layui-input" type="text" value="直播预告，课程名称：{1}，章节名称：{2}，开播时间：{3}" readonly="readonly"></td>
                <td><span class="kg-copy layui-btn" data-clipboard-target="#tc-live-begin">复制</span></td>
            </tr>
""", ''),
])

E.edit(p('public/static/home/js/teacher.console.js'), [
    ("""    /**
     * 直播推流
     */
    $('.btn-live-push').on('click', function () {
        var url = $(this).data('url');
        layer.open({
            type: 2,
            title: '直播推流',
            content: [url, 'no'],
            area: ['640px', '420px'],
        });
    });

""", ''),
])

E.edit(p('public/static/home/js/teacher.show.js'), [
    ("""    if ($('#tab-live').length > 0) {
        var $tabLive = $('#tab-live');
        helper.ajaxLoadHtml($tabLive.data('url'), $tabLive.attr('id'));
    }

""", ''),
    ("""
    if ($('#tab-offline').length > 0) {
        var $tabOffline = $('#tab-offline');
        helper.ajaxLoadHtml($tabOffline.data('url'), $tabOffline.attr('id'));
    }
""", ''),
])

print('阶段一残余清理完成')
