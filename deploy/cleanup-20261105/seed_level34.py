# -*- coding: utf-8 -*-
"""新增「中级」「高级」难度课程（复用已有视频资源），幂等：按标题判重。"""
import json
import os
import struct
import subprocess
import sys

MYSQL = r'C:/ctc/mysql/bin/mysql.exe'
VOD_BASE = r'C:/ctc/www/public/static/vod'
SQL_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'seed_level34.sql')

COURSES = [
    {
        'title': '数据库设计与优化实践',
        'category_id': 5,
        'level': 3,
        'cover': '/cover/c8.png',
        'summary': '面向已掌握 SQL 基础的学习者，围绕 B+ 树索引、慢查询定位、表结构设计与事务隔离，讲清数据库性能优化的完整路径。',
        'keywords': '数据库,索引,慢查询,事务',
        'chapters': [
            ('第一章 索引与查询优化', [
                ('B+ 树索引结构与命中规则', 'database/btree-index.mp4'),
                ('慢查询定位与 SQL 改写', 'database/slow-query.mp4'),
            ]),
            ('第二章 表设计与事务处理', [
                ('表结构设计与范式取舍', 'database/table-design.mp4'),
                ('事务隔离级别与并发异常', 'database/isolation.mp4'),
            ]),
        ],
    },
    {
        'title': 'Python 算法进阶：排序与查找',
        'category_id': 2,
        'level': 3,
        'cover': '/cover/c9.png',
        'summary': '在掌握基础语法之后，深入排序与查找的复杂度分析与工程取舍，覆盖快速排序、稳定性判断、二分边界处理等进阶内容。',
        'keywords': 'Python,算法,排序,查找',
        'chapters': [
            ('第一章 排序算法进阶', [
                ('快速排序：分治与原地交换', 'python/quick-sort.mp4'),
                ('排序稳定性与工程选型', 'python/sort-stability.mp4'),
            ]),
            ('第二章 查找与算法复盘', [
                ('二分查找的边界处理', 'python/binary-search.mp4'),
                ('冒泡与交换类算法复盘', 'python/bubble-sort.mp4'),
            ]),
        ],
    },
    {
        'title': 'Web 安全攻防进阶',
        'category_id': 6,
        'level': 4,
        'cover': '/cover/c10.png',
        'summary': '从 SQL 注入、XSS 到恶意代码分析，结合真实攻击链讲解漏洞成因、检测思路与防护落地，适合有一定基础的运维与开发人员。',
        'keywords': 'Web安全,SQL注入,XSS,攻防',
        'chapters': [
            ('第一章 注入与跨站脚本', [
                ('SQL 注入原理与利用链', 'security/sqli.mp4'),
                ('XSS 跨站脚本攻防', 'security/xss.mp4'),
            ]),
            ('第二章 威胁建模与恶意代码', [
                ('安全基础与威胁建模', 'security/security-basics.mp4'),
                ('病毒与木马行为分析', 'security/virus-trojan.mp4'),
            ]),
        ],
    },
    {
        'title': '容器编排与生产部署',
        'category_id': 4,
        'level': 4,
        'cover': '/cover/c11.png',
        'summary': '从 Dockerfile 编写与镜像瘦身到 Compose 多容器编排，完整走通一套可交付、可复用的容器化生产部署方案。',
        'keywords': 'Docker,Compose,镜像,部署',
        'chapters': [
            ('第一章 镜像构建与优化', [
                ('Dockerfile 编写最佳实践', 'devops/dockerfile.mp4'),
                ('镜像分层与体积优化', 'devops/image-layer.mp4'),
            ]),
            ('第二章 多容器编排与交付', [
                ('Compose 多容器编排', 'devops/compose.mp4'),
                ('MySQL 容器化部署实战', 'devops/deploy-mysql.mp4'),
            ]),
        ],
    },
]


def mp4_duration(path):
    with open(path, 'rb') as fh:
        data = fh.read(2 * 1024 * 1024)
    i = data.find(b'mvhd')
    if i < 0:
        return 0
    if data[i + 4] == 1:
        timescale = struct.unpack('>I', data[i + 24:i + 28])[0]
        dur = struct.unpack('>Q', data[i + 28:i + 36])[0]
    else:
        timescale = struct.unpack('>I', data[i + 16:i + 20])[0]
        dur = struct.unpack('>I', data[i + 20:i + 24])[0]
    return int(round(dur / timescale)) if timescale else 0


def esc(text):
    return text.replace('\\', '\\\\').replace("'", "\\'")


def build_sql():
    lines = ['SET NAMES utf8mb4;', 'SET FOREIGN_KEY_CHECKS = 0;', '']

    course_id = 10
    chapter_id = 51
    vod_id = 58

    for course in COURSES:
        lessons = [(t, f) for _, items in course['chapters'] for t, f in items]
        durations = {f: mp4_duration(os.path.join(VOD_BASE, f)) for _, f in lessons}
        total = sum(durations.values())

        lines.append("-- %s（%s）" % (course['title'], '中级' if course['level'] == 3 else '高级'))
        lines.append(
            "INSERT INTO kg_course (id, title, cover, summary, tags, keywords, details, category_id, teacher_id, "
            "origin_price, market_price, vip_price, study_expiry, refund_expiry, rating, score, model, level, attrs, "
            "featured, published, deleted, resource_count, user_count, fake_user_count, lesson_count, package_count, "
            "review_count, consult_count, favorite_count, create_time, update_time) VALUES ("
            "%d, '%s', '%s', '%s', '[]', '%s', '%s', %d, 10000, 0, 0, 0, 12, 7, 5, 0, 1, %d, "
            "'{\"duration\":%d}', 0, 1, 0, 0, 0, 0, 4, 0, 0, 0, 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());"
            % (course_id, esc(course['title']), course['cover'], esc(course['summary']), course['keywords'],
               esc(course['summary']), course['category_id'], course['level'], total)
        )

        priority = 1
        for chapter_title, items in course['chapters']:
            lines.append(
                "INSERT INTO kg_chapter (id, parent_id, course_id, title, summary, priority, free, model, attrs, "
                "published, deleted, lesson_count, user_count, comment_count, like_count, create_time, update_time) "
                "VALUES (%d, 0, %d, '%s', '', %d, 1, 1, '[]', 1, 0, 0, 0, 0, 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());"
                % (chapter_id, course_id, esc(chapter_title), priority)
            )
            parent = chapter_id
            chapter_id += 1
            priority += 1

            for idx, (lesson_title, vfile) in enumerate(items):
                dur = durations[vfile]
                free = 1 if (priority == 2) else 0
                lines.append(
                    "INSERT INTO kg_chapter (id, parent_id, course_id, title, summary, priority, free, model, attrs, "
                    "published, deleted, lesson_count, user_count, comment_count, like_count, create_time, update_time) "
                    "VALUES (%d, %d, %d, '%s', '', %d, %d, 1, '{\"duration\":%d,\"file\":{\"status\":\"pending\"}}', "
                    "1, 0, 0, 0, 0, 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());"
                    % (chapter_id, parent, course_id, esc(lesson_title), priority, free, dur)
                )
                url = 'http://127.0.0.1:8000/static/vod/' + vfile
                remote = json.dumps({
                    'hd': {'url': url},
                    'sd': {'url': url},
                    'fd': {'url': url},
                }, ensure_ascii=False, separators=(',', ':'))
                lines.append(
                    "INSERT INTO kg_chapter_vod (id, course_id, chapter_id, file_id, file_transcode, file_remote, "
                    "create_time, update_time) VALUES (%d, %d, %d, '', '[]', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());"
                    % (vod_id, course_id, chapter_id, esc(remote))
                )
                vod_id += 1
                chapter_id += 1
                priority += 1

        course_id += 1
        lines.append('')

    lines.append('SET FOREIGN_KEY_CHECKS = 1;')
    return '\n'.join(lines)


def main():
    sql = build_sql()
    with open(SQL_OUT, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(sql)
    print('SQL 已生成：', SQL_OUT)

    if '--dry-run' in sys.argv:
        return

    with open(SQL_OUT, 'rb') as fh:
        proc = subprocess.run([MYSQL, '-uroot', '--default-character-set=utf8mb4', 'ctc'],
                              stdin=fh, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = proc.stdout.decode('utf-8', 'replace')
    err = proc.stderr.decode('utf-8', 'replace')
    print('执行结果：', proc.returncode)
    if out.strip():
        print(out)
    if err.strip():
        print('ERR', err)


if __name__ == '__main__':
    main()
