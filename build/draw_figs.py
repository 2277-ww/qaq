#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Generate figures for the SRS (state machine + sequence diagram)."""
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(BASE, "docs", "figs")
os.makedirs(OUTDIR, exist_ok=True)

SS = 2  # supersample

FONT_REG = "C:/Windows/Fonts/msyh.ttc"
FONT_BOLD = "C:/Windows/Fonts/msyhbd.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size * SS)


def text_center(d, xy, s, f, fill):
    x, y = xy
    bbox = d.textbbox((0, 0), s, font=f)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((x - w / 2 - bbox[0], y - h / 2 - bbox[1]), s, font=f, fill=fill)


def box(d, x, y, w, h, fill, outline, label, code=None, size=24, radius=10):
    d.rounded_rectangle([x * SS, y * SS, (x + w) * SS, (y + h) * SS],
                        radius=radius * SS, fill=fill, outline=outline, width=2 * SS)
    f1 = font(size, bold=True)
    if code:
        text_center(d, ((x + w / 2) * SS, (y + h / 2 - 12) * SS), label, f1, (0x1A, 0x1A, 0x1A))
        text_center(d, ((x + w / 2) * SS, (y + h / 2 + 16) * SS), code, font(15), (0x59, 0x59, 0x59))
    else:
        text_center(d, ((x + w / 2) * SS, (y + h / 2) * SS), label, f1, (0x1A, 0x1A, 0x1A))


def arrow_line(d, pts, color=(0x40, 0x40, 0x40), width=2.0, head=12, dashed=False):
    pts = [(p[0] * SS, p[1] * SS) for p in pts]
    if dashed:
        for i in range(len(pts) - 1):
            x1, y1 = pts[i]
            x2, y2 = pts[i + 1]
            dist = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
            step = 12 * SS
            n = max(int(dist // step), 1)
            for k in range(n):
                t1, t2 = k / n, (k + 0.55) / n
                d.line([(x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1),
                        (x1 + (x2 - x1) * t2, y1 + (y2 - y1) * t2)], fill=color, width=int(width * SS))
    else:
        d.line(pts, fill=color, width=int(width * SS), joint="curve")
    # arrow head at last segment
    x1, y1 = pts[-2]
    x2, y2 = pts[-1]
    dx, dy = x2 - x1, y2 - y1
    length = max((dx * dx + dy * dy) ** 0.5, 1)
    ux, uy = dx / length, dy / length
    px, py = -uy, ux
    h = head * SS
    p1 = (x2 - ux * h + px * h * 0.42, y2 - uy * h + py * h * 0.42)
    p2 = (x2 - ux * h - px * h * 0.42, y2 - uy * h - py * h * 0.42)
    d.polygon([(x2, y2), p1, p2], fill=color)


def label(d, xy, s, size=17, color=(0x33, 0x33, 0x33), bold=False, bg=None, pad=4):
    f = font(size, bold)
    bbox = d.textbbox((0, 0), s, font=f)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = xy[0] * SS - w / 2 - bbox[0], xy[1] * SS - h / 2 - bbox[1]
    if bg:
        d.rectangle([x - pad * SS, y - pad * SS, x + w + pad * SS, y + h + pad * SS], fill=bg)
    d.text((x, y), s, font=f, fill=color)


# ---------------- figure 1: course state machine ----------------

def fig_state():
    W, H = 1620, 700
    img = Image.new("RGB", (W * SS, H * SS), "white")
    d = ImageDraw.Draw(img)

    bw, bh = 236, 96
    y1, y2 = 150, 430
    xs = {"draft": 60, "pending": 420, "pub": 780, "arch": 1140}
    boxes = {
        "draft": (xs["draft"], y1, "草稿", "DRAFT", "#F2F5FA", "#1F3864"),
        "pending": (xs["pending"], y1, "待审核", "PENDING_REVIEW", "#FFF6E6", "#B07A18"),
        "pub": (xs["pub"], y1, "已发布", "PUBLISHED", "#EAF4EA", "#2E7D32"),
        "arch": (xs["arch"], y1, "已归档", "ARCHIVED", "#F0F0F0", "#6E6E6E"),
        "reject": (xs["pending"], y2, "已驳回", "REJECTED", "#FBEDED", "#A93226"),
    }
    for k, (x, y, cn, code, fill, stroke) in boxes.items():
        box(d, x, y, bw, bh, fill, stroke, cn, code, size=23)

    # draft <-> pending (two parallel arrows)
    arrow_line(d, [(xs["draft"] + bw, y1 + 34), (xs["pending"], y1 + 34)])
    label(d, ((xs["draft"] + bw + xs["pending"]) / 2, y1 + 16), "提交审核", 16, bg="white")
    arrow_line(d, [(xs["pending"], y1 + 66), (xs["draft"] + bw, y1 + 66)])
    label(d, ((xs["draft"] + bw + xs["pending"]) / 2, y1 + 84), "撤回", 16, bg="white")

    # pending -> published
    arrow_line(d, [(xs["pending"] + bw, y1 + 34), (xs["pub"], y1 + 34)])
    label(d, ((xs["pending"] + bw + xs["pub"]) / 2, y1 + 16), "审核通过", 16, bg="white")
    arrow_line(d, [(xs["pub"], y1 + 66), (xs["pending"] + bw, y1 + 66)])
    label(d, ((xs["pending"] + bw + xs["pub"]) / 2, y1 + 84), "重新提审", 16, bg="white")

    # published -> archived
    arrow_line(d, [(xs["pub"] + bw, y1 + 48), (xs["arch"], y1 + 48)])
    label(d, ((xs["pub"] + bw + xs["arch"]) / 2, y1 + 26), "归档审批通过", 15, bg="white")
    label(d, ((xs["pub"] + bw + xs["arch"]) / 2, y1 + 70), "强制下架", 15, bg="white")

    # pending -> rejected (down) and back (up)
    cx1 = xs["pending"] + bw / 2 - 26
    cx2 = xs["pending"] + bw / 2 + 26
    arrow_line(d, [(cx1, y1 + bh), (cx1, y2)])
    label(d, (cx1 - 58, (y1 + bh + y2) / 2), "审核驳回", 15, bg="white")
    arrow_line(d, [(cx2, y2), (cx2, y1 + bh)])
    label(d, (cx2 + 96, (y1 + bh + y2) / 2), "修改后重新提交", 15, bg="white")

    # archived -> pending restore (elbow, routed above boxes to avoid overlap)
    gx = 358          # vertical channel between DRAFT and PENDING
    arrow_line(d, [(xs["arch"] + bw / 2, y1 + bh), (xs["arch"] + bw / 2, 618),
                   (gx, 618), (gx, 108), (xs["pending"] + bw / 2, 108),
                   (xs["pending"] + bw / 2, y1)])
    label(d, (760, 598), "恢复发布（须重新审核）", 15, bg="white")

    # note
    label(d, (W / 2, 660), "说明：已发布状态下的“申请归档／撤回归档申请”由责任教师发起，审批前不改变课程状态。",
          15, (0x59, 0x59, 0x59))

    img = img.resize((W, H), Image.LANCZOS)
    path = os.path.join(OUTDIR, "fig_state.png")
    img.save(path, dpi=(200, 200))
    return path


# ---------------- figure 2: prerequisite sequence ----------------

def fig_seq():
    W, H = 1620, 990
    img = Image.new("RGB", (W * SS, H * SS), "white")
    d = ImageDraw.Draw(img)

    def vline_dashed(x, y1, y2, color=(0xC8, 0xC8, 0xC8), width=1.2, step=11):
        y = y1
        while y < y2:
            d.line([(x * SS, y * SS), (x * SS, min(y + step * 0.55, y2) * SS)],
                   fill=color, width=int(width * SS))
            y += step

    parts = [
        (200, "实训工坊", "#FFF6E6", "#B07A18"),
        (600, "学生", "#F2F5FA", "#1F3864"),
        (1010, "自学平台", "#EAF4EA", "#2E7D32"),
        (1420, "个人成长档案", "#F0F0F0", "#6E6E6E"),
    ]
    top, boxw, boxh = 40, 220, 58
    for x, name, fill, stroke in parts:
        box(d, x - boxw / 2, top, boxw, boxh, fill, stroke, name, None, size=19, radius=8)
        vline_dashed(x, top + boxh + 6, H - 80)

    def msg(y, x1, x2, text, dashed=False, num=None):
        arrow_line(d, [(x1, y), (x2, y)], color=(0x33, 0x33, 0x33), width=1.8, head=11, dashed=dashed)
        mid = (x1 + x2) / 2
        label(d, (mid, y - 19), text, 15, bg="white")
        if num:
            d.ellipse([(x1 + 6) * SS, (y - 40) * SS, (x1 + 34) * SS, (y - 12) * SS], fill="#1F3864")
            text_center(d, ((x1 + 20) * SS, (y - 26) * SS), str(num), font(14, True), (255, 255, 255))

    def selfmsg(y, x, text, num=None):
        arrow_line(d, [(x, y), (x + 70, y), (x + 70, y + 34), (x + 4, y + 34)],
                   color=(0x33, 0x33, 0x33), width=1.6, head=10)
        label(d, (x + 190, y + 16), text, 15, bg="white")
        if num:
            d.ellipse([(x + 6) * SS, (y - 40) * SS, (x + 34) * SS, (y - 12) * SS], fill="#1F3864")
            text_center(d, ((x + 20) * SS, (y - 26) * SS), str(num), font(14, True), (255, 255, 255))

    y = 170
    step = 76
    # 1 学生 clicks in 工坊
    msg(y, 600, 200, "① 查看项目前置要求，点击“前往学习”")
    y += step
    # 2 学生 -> 平台 deep link
    msg(y, 600, 1010, "② 深链跳转（携带 courseId 与来源标识）")
    y += step
    # 3 platform self: SSO check
    selfmsg(y, 1010, "③ 校验登录态，未登录走 SSO 并回跳")
    y += step + 34
    # 4 platform -> student
    msg(y, 1010, 600, "④ 返回课程详情（含来源提示条）", dashed=True)
    y += step
    # 5 student -> platform progress
    msg(y, 600, 1010, "⑤ 学习并上报进度（心跳 / 滚动 / 离开）")
    y += step
    # 6 self judgement
    selfmsg(y, 1010, "⑥ 合并进度，判定课程完成")
    y += step + 34
    # 7 event to 工坊
    msg(y, 1010, 200, "⑦ 投递 course.completed 事件（P95 ≤ 5s）")
    y += step
    # 8 工坊 fallback query
    msg(y, 200, 1010, "⑧ 兜底复核：OPEN-01 查询完成状态", dashed=True)
    y += step
    # 9 to profile
    msg(y, 1010, 1420, "⑨ 归集：OPEN-04 / 事件")

    label(d, (W / 2, H - 26), "说明：第 ⑧ 步为工坊侧的兜底动作，非必需；本平台不参与项目准入判定。",
          15, (0x59, 0x59, 0x59))

    img = img.resize((W, H), Image.LANCZOS)
    path = os.path.join(OUTDIR, "fig_seq.png")
    img.save(path, dpi=(200, 200))
    return path


if __name__ == "__main__":
    print(fig_state())
    print(fig_seq())
