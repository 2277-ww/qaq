# -*- coding: utf-8 -*-
"""
生成「自学平台」品牌视觉资源：
  - logo.png    400x120 透明底（深色导航栏使用）
  - logo_dark.png 400x120 透明底（浅色背景使用，深色字）
  - favicon.ico 多尺寸图标
设计：圆角方形渐变徽标（蓝→青）+ 白色展开书本 + 金色星芒 + 中文粗体字标。
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

S = 4  # 超采样倍数

OUT_DIR = r"C:\ctc\www\public\static"

NAME = "自学平台"
SUBTITLE = "SELF-LEARNING"

C_GRAD_TOP = (37, 99, 235)      # #2563EB
C_GRAD_BOTTOM = (34, 211, 238)  # #22D3EE
C_INK = (255, 255, 255)
C_SUB_LIGHT = (156, 172, 196)
C_SUB_DARK = (110, 124, 145)
C_ACCENT = (245, 196, 81)
C_FOLD_LIGHT = (125, 196, 245)


def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception as e:
        print("font fallback:", path, e)
        return ImageFont.load_default()


def vertical_gradient(w, h, c1, c2):
    grad = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(grad)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line(
            [(0, y), (w, y)],
            fill=(
                int(c1[0] + (c2[0] - c1[0]) * t),
                int(c1[1] + (c2[1] - c1[1]) * t),
                int(c1[2] + (c2[2] - c1[2]) * t),
                255,
            ),
        )
    return grad


def draw_sparkle(d, cx, cy, r, color):
    k = 0.26
    pts = [
        (cx, cy - r),
        (cx + r * k, cy - r * k),
        (cx + r, cy),
        (cx + r * k, cy + r * k),
        (cx, cy + r),
        (cx - r * k, cy + r * k),
        (cx - r, cy),
        (cx - r * k, cy - r * k),
    ]
    d.polygon(pts, fill=color)


def build_emblem(size):
    """返回 size x size 的徽标（渐变圆角方 + 白色书本）"""
    w = h = size
    emblem = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    radius = int(w * 0.26)
    grad = vertical_gradient(w, h, C_GRAD_TOP, C_GRAD_BOTTOM)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    emblem.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(emblem)

    # 书本几何（以徽标为坐标系，相对比例）
    cx = w * 0.50
    top_y = h * 0.34
    spine_bottom = h * 0.72
    left_x = w * 0.21
    right_x = w * 0.79
    outer_top = h * 0.42
    outer_bottom = h * 0.79

    left_page = [(cx, top_y), (left_x, outer_top), (left_x, outer_bottom), (cx, spine_bottom)]
    right_page = [(cx, top_y), (right_x, outer_top), (right_x, outer_bottom), (cx, spine_bottom)]

    d.polygon(left_page, fill=C_INK)
    d.polygon(right_page, fill=C_INK)

    # 书脊折线
    d.line([(cx, top_y), (cx, spine_bottom)], fill=C_FOLD_LIGHT, width=max(2, int(w * 0.016)))

    # 页面纹理线（每侧两条）
    lw = max(2, int(w * 0.014))
    for i, t in enumerate((0.28, 0.52)):
        y_l = outer_top + (outer_bottom - outer_top) * (0.30 + t * 0.45)
        d.line(
            [(left_x + w * 0.055, y_l + h * 0.012), (cx - w * 0.075, y_l - h * 0.018)],
            fill=C_FOLD_LIGHT,
            width=lw,
        )
        d.line(
            [(right_x - w * 0.055, y_l + h * 0.012), (cx + w * 0.075, y_l - h * 0.018)],
            fill=C_FOLD_LIGHT,
            width=lw,
        )

    # 星芒点缀
    draw_sparkle(d, w * 0.775, h * 0.245, w * 0.075, C_ACCENT)

    return emblem


def build_logo(text_color, sub_color, sparkle_color=None):
    W, H = 400 * S, 120 * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    emblem_size = 84 * S
    emblem = build_emblem(emblem_size)
    if sparkle_color:
        # 星芒已在 build_emblem 内部绘制，这里仅用于占位扩展
        pass
    img.paste(emblem, (8 * S, 18 * S), emblem)

    font_main = load_font(r"C:\Windows\Fonts\msyhbd.ttc", 46 * S)
    d = ImageDraw.Draw(img)
    d.text((106 * S, 57 * S), NAME, font=font_main, fill=text_color, anchor="lm")

    text_width = d.textlength(NAME, font=font_main)

    # 副标题（手工字距）
    font_sub = load_font(r"C:\Windows\Fonts\msyhbd.ttc", 11 * S)
    x = 108 * S
    y = 84 * S
    for ch in SUBTITLE:
        d.text((x, y), ch, font=font_sub, fill=sub_color)
        x += d.textlength(ch, font=font_sub) + 2.2 * S

    sub_width = x - 108 * S

    # 按内容裁切，去掉右侧空白，保证在导航栏中充分利用可用空间
    content_width = max(106 * S + text_width, 108 * S + sub_width) + 10 * S
    img = img.crop((0, 0, int(content_width), H))

    bbox = img.getbbox()
    if bbox:
        img = img.crop((max(0, bbox[0] - 2 * S), max(0, bbox[1] - 2 * S),
                        min(img.width, bbox[2] + 2 * S), min(img.height, bbox[3] + 2 * S)))

    target_h = 120
    target_w = int(round(img.width * target_h / img.height))

    logo = img.resize((target_w, target_h), Image.LANCZOS)

    # 四周留白，避免在高度受限的导航栏中被视觉裁切
    pad_x, pad_y = 6, 6
    canvas = Image.new("RGBA", (logo.width + pad_x * 2, logo.height + pad_y * 2), (0, 0, 0, 0))
    canvas.alpha_composite(logo, (pad_x, pad_y))

    return canvas


def main():
    if not os.path.isdir(OUT_DIR):
        print("output dir not found:", OUT_DIR)
        sys.exit(1)

    logo_light = build_logo(C_INK, C_SUB_LIGHT)
    logo_light.save(os.path.join(OUT_DIR, "brand-logo.png"))
    print("saved brand-logo.png", logo_light.size)

    logo_dark = build_logo((28, 38, 56), C_SUB_DARK)
    logo_dark.save(os.path.join(OUT_DIR, "brand-logo-dark.png"))
    print("saved brand-logo-dark.png", logo_dark.size)

    icon = build_emblem(256).resize((64, 64), Image.LANCZOS)
    icon.save(
        os.path.join(OUT_DIR, "favicon.ico"),
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64)],
    )
    print("saved favicon.ico")


if __name__ == "__main__":
    main()
