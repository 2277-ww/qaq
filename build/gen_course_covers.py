# -*- coding: utf-8 -*-
"""生成新增中级/高级课程的封面（与既有封面同版式，换配色与文案）。"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = r'C:/ctc/www/public/static/cover'
FONT_BD = r'C:/Windows/Fonts/msyhbd.ttc'
FONT_RG = r'C:/Windows/Fonts/msyh.ttc'

W, H = 640, 360
S = 3  # 超采样倍数

COURSES = [
    ('c8.png', '数据库设计与优化', 'B+Tree / 慢查询 / 表设计', '中级', (18, 60, 74), (32, 104, 120)),
    ('c9.png', 'Python 算法进阶', '排序 / 查找 / 稳定性', '中级', (46, 34, 82), (86, 66, 140)),
    ('c10.png', 'Web 安全攻防进阶', 'SQL 注入 / XSS / 恶意代码', '高级', (74, 28, 34), (132, 54, 46)),
    ('c11.png', '容器编排与生产部署', 'Dockerfile / Compose / 交付', '高级', (26, 42, 62), (44, 78, 108)),
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def build(name, title, sub, level, c1, c2):
    img = Image.new('RGB', (W * S, H * S), c1)
    px = img.load()
    for y in range(H * S):
        t = y / float(H * S - 1)
        col = lerp(c1, c2, t)
        for x in range(W * S):
            t2 = x / float(W * S - 1)
            px[x, y] = lerp(col, c2, 0.18 * t2)

    draw = ImageDraw.Draw(img, 'RGBA')

    # 右侧装饰圆环
    for cx, cy, r, wd in [(690, 40, 190, 2), (700, 430, 260, 2), (560, 330, 130, 2)]:
        draw.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S],
                     outline=(255, 255, 255, 70), width=wd * S)

    f_title = ImageFont.truetype(FONT_BD, 44 * S)
    f_sub = ImageFont.truetype(FONT_RG, 20 * S)
    f_tag = ImageFont.truetype(FONT_BD, 17 * S)

    x0, y0 = 60 * S, 150 * S

    # 难度标签
    tw = draw.textlength(level, font=f_tag)
    draw.rounded_rectangle([x0, y0 - 46 * S, x0 + tw + 26 * S, y0 - 18 * S], radius=4 * S,
                           fill=(255, 255, 255, 40))
    draw.text((x0 + 13 * S, y0 - 44 * S), level, font=f_tag, fill=(255, 255, 255, 220))

    draw.text((x0, y0), title, font=f_title, fill=(255, 255, 255))
    draw.text((x0, y0 + 62 * S), sub, font=f_sub, fill=(214, 226, 240))

    # 强调线
    draw.rectangle([x0, y0 + 108 * S, x0 + 96 * S, y0 + 112 * S], fill=(200, 172, 106))

    img = img.resize((W, H), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print('生成', path)


for item in COURSES:
    build(*item)
