#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, re, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from docx_lib import (BASE, DOCS, FIGS, OUT, NAVY, DARK, GRAY, ACCENT, WHITE,
                      BODY_CN, HEAD_CN, LATIN, CONTENT_W,
                      set_run_font, shade, p_border, add_field, add_toc_field,
                      add_inline, add_table, setup_styles, page_setup,
                      build_header_footer, restart_numbering)

TITLE = "自学平台软件需求规格说明书"
DOC_NO = "SRS-SELFSTUDY-01"
VER = "V1.0"
DATE_CN = "2026 年 11 月"
DATE_ISO = "2026-11-03"

# 少数表格含不可断行的路径/URL，内容加权的宽度会把它们挤成两截，这里按表头覆盖列宽（单位 cm）。
TBL_WIDTHS = {
    ("组件", "版本", "获取来源", "落盘路径", "作用"): [1.9, 2.45, 4.1, 4.35, 2.6],
}


def table_width_override(rows):
    spec = TBL_WIDTHS.get(tuple(c.strip() for c in rows[0]))
    return [Cm(x) for x in spec] if spec else None


def spacer(doc, pts=6):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.0
    r = p.add_run("")
    set_run_font(r, size=pts)
    return p


def minor_title(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(10)
    p.paragraph_format.keep_with_next = True
    r = p.add_run(text)
    set_run_font(r, cn=HEAD_CN, size=14, bold=True, color=NAVY)
    p_border(p, 'bottom', '1F3864', 6, 5)
    return p


def build_cover(doc):
    spacer(doc, 46)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("警院 WeChat 全生态 · 五平台系列文档")
    set_run_font(r, cn=HEAD_CN, size=10.5, color=GRAY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(46)
    r = p.add_run("论坛 · 自学平台 · 考试平台 · 实训工坊 · 成果展示广场")
    set_run_font(r, cn=HEAD_CN, size=9, color=GRAY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("自 学 平 台")
    set_run_font(r, cn=HEAD_CN, size=34, bold=True, color=NAVY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(10)
    r = p.add_run("软件需求规格说明书")
    set_run_font(r, cn=HEAD_CN, size=26, bold=True, color=NAVY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(8)
    r = p.add_run("Software Requirements Specification")
    set_run_font(r, cn=HEAD_CN, size=11, color=ACCENT)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(56)
    r = p.add_run("依据《五平台前端与功能联动约束规范 V1.0》编制")
    set_run_font(r, cn=HEAD_CN, size=9.5, color=GRAY)

    # rule
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(30)
    r = p.add_run("─" * 34)
    set_run_font(r, cn=HEAD_CN, size=9, color=RGBColor(0xBF, 0xC7, 0xD6))

    for line in (
        "文档版本：%s          文档编号：%s" % (VER, DOC_NO),
        "文档状态：评审稿            密　　级：内部",
    ):
        p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(6)
        r = p.add_run(line)
        set_run_font(r, cn=HEAD_CN, size=10.5, color=DARK)

    spacer(doc, 60)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("独立项目 · 独立工程 · 独立部署 · 统一身份 · 统一规范")
    set_run_font(r, cn=HEAD_CN, size=10, color=GRAY)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(DATE_CN)
    set_run_font(r, cn=HEAD_CN, size=11, color=NAVY)


def build_front_matter(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)

    minor_title(doc, "文 档 信 息")
    rows = [
        ["文档名称", "警院 WeChat 全生态 · 自学平台软件需求规格说明书", "文档编号", DOC_NO],
        ["版本号", VER, "文档状态", "评审稿"],
        ["密　　级", "内部", "编写日期", DATE_ISO],
        ["适用项目", "自学平台（独立工程，不与其他平台合并）", "关联规范", "五平台前端与功能联动约束规范 V1.0"],
        ["读者对象", "业务负责人、产品、设计与研发、测试、跨平台联调方", "变更控制", "需求条目变更须更新修订记录并通知联调方"],
        ["适用范围", "自学平台全部功能需求、非功能需求、数据与接口约定", "不适用范围", "考试判卷、项目审批、项目过程管理、成果展示"],
    ]
    add_table(doc, rows, widths=[Cm(2.35), Cm(6.35), Cm(2.35), Cm(4.15)])

    spacer(doc, 10)
    minor_title(doc, "修 订 记 录")
    rows = [
        ["版本", "日期", "修订人", "修订说明", "状态"],
        ["V0.1", "2026-10-18", "产品组", "形成需求初稿，明确平台定位与范围", "草稿"],
        ["V0.5", "2026-10-27", "产品组", "补充三条核心业务流程、状态机与对外接口能力", "内部评审"],
        ["V0.9", "2026-11-01", "产品组", "按约束规范核对接口、错误码、时间与事件格式；补充非功能需求与数据需求", "内部评审"],
        ["V1.0", "2026-11-03", "产品组", "定稿：补齐权限点、追溯矩阵与待确认事项，形成评审稿", "评审稿"],
    ]
    add_table(doc, rows, widths=[Cm(1.7), Cm(2.5), Cm(1.9), Cm(7.3), Cm(1.9)])

    spacer(doc, 10)
    minor_title(doc, "阅 读 指 引")
    guide = [
        ("第 1 章", "说明平台背景、定位、范围与角色，是理解边界的基础，建议所有读者通读。"),
        ("第 2 章", "为强制约束，与《五平台前端与功能联动约束规范 V1.0》保持一致，任何设计不得偏离；其中 2.5.2 边界红线为一票否决项。"),
        ("第 3 章", "描述课程发布审核、学习进度更新、前置必修联动三条核心流程及状态机，是开发与测试的流程依据。"),
        ("第 4 章", "按学生、教师、管理员三端逐条列出功能需求，并区分对外公开接口能力与业务事件；编号 FR-、OPEN-、EVT- 可直接用于任务拆分与验收。"),
        ("第 5 章", "非功能需求，含性能、安全、兼容性与可维护性指标，均可量化验收。"),
        ("第 6、7 章", "数据与接口约定，是跨平台联调的依据；接口字段以 OpenAPI 契约为准，本章为要点说明。"),
        ("第 8 章", "附录：状态字典、业务事件契约、权限点、追溯矩阵与待确认事项，联调前须逐项确认。"),
    ]
    for k, v in guide:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(0.9)
        p.paragraph_format.first_line_indent = Cm(-0.9)
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(k + "　")
        set_run_font(r, cn=HEAD_CN, size=10.5, bold=True, color=NAVY)
        add_inline(p, v, size=10.5)

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    minor_title(doc, "目　　录")
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    add_toc_field(p)


# ---------------- markdown rendering ----------------

class Renderer:
    def __init__(self, doc):
        self.doc = doc
        self.chapter = 0
        self.tbl_idx = 0
        self.fig_idx = 0
        self.first_h1 = True

    def add_caption(self, text):
        p = self.doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.keep_with_next = True
        r = p.add_run(text)
        set_run_font(r, cn=HEAD_CN, size=9, bold=True, color=NAVY)

    def render(self, lines):
        i = 0
        pending_caption = None
        while i < len(lines):
            raw = lines[i].rstrip("\n")
            line = raw.strip()
            if not line:
                i += 1
                continue

            if line == "[[PAGEBREAK]]":
                self.doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
                i += 1
                continue

            if line.startswith("# "):
                title = line[2:].strip()
                m = re.match(r'^(\d+)', title)
                if m:
                    self.chapter = int(m.group(1))
                    self.tbl_idx = 0
                    self.fig_idx = 0
                h = self.doc.add_heading(level=1)
                h.paragraph_format.page_break_before = not self.first_h1
                self.first_h1 = False
                r = h.add_run(title)
                set_run_font(r, cn=HEAD_CN, size=17, bold=True, color=NAVY)
                p_border(h, 'bottom', '1F3864', 8, 6)
                i += 1
                continue

            if line.startswith("#### "):
                title = line[5:].strip()
                h = self.doc.add_heading(level=4)
                h.paragraph_format.space_before = Pt(11)
                h.paragraph_format.space_after = Pt(3)
                h.paragraph_format.left_indent = Cm(0.0)
                r = h.add_run("　" + title)
                set_run_font(r, cn=HEAD_CN, size=10.5, bold=True, color=ACCENT)
                shade(h._p.get_or_add_pPr(), 'EDF2F9')
                p_border(h, 'left', '1F4E79', 18, 4)
                i += 1
                continue

            if line.startswith("### "):
                h = self.doc.add_heading(level=3)
                r = h.add_run(line[4:].strip())
                set_run_font(r, cn=HEAD_CN, size=11.5, bold=True, color=ACCENT)
                i += 1
                continue

            if line.startswith("## "):
                h = self.doc.add_heading(level=2)
                r = h.add_run(line[3:].strip())
                set_run_font(r, cn=HEAD_CN, size=13.5, bold=True, color=NAVY)
                i += 1
                continue

            if line.startswith("[表]"):
                pending_caption = line[3:].strip()
                i += 1
                continue

            if line.startswith("[IMG:"):
                m = re.match(r'\[IMG:([^\]]+)\]\s*(.*)$', line)
                fname, cap = m.group(1), m.group(2)
                path = os.path.join(FIGS, fname)
                if os.path.exists(path):
                    from PIL import Image as PILImage
                    w, hgt = PILImage.open(path).size
                    target_w = Cm(15.0)
                    p = self.doc.add_paragraph()
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    p.paragraph_format.space_before = Pt(8)
                    p.paragraph_format.space_after = Pt(2)
                    p.paragraph_format.keep_with_next = True
                    p.add_run().add_picture(path, width=target_w)
                    self.fig_idx += 1
                    q = self.doc.add_paragraph()
                    q.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    q.paragraph_format.space_after = Pt(8)
                    r = q.add_run(cap or ("图 %d-%d" % (self.chapter, self.fig_idx)))
                    set_run_font(r, cn=HEAD_CN, size=9, bold=True, color=NAVY)
                i += 1
                continue

            # table block
            if line.startswith("|"):
                block = []
                while i < len(lines) and lines[i].strip().startswith("|"):
                    block.append(lines[i].strip())
                    i += 1
                rows = []
                for bi, tl in enumerate(block):
                    if re.match(r'^\|[\s\-:\|]+\|$', tl):
                        continue
                    cells = [c.strip() for c in tl.strip().strip("|").split("|")]
                    rows.append(cells)
                if not rows:
                    continue
                ncol = max(len(r) for r in rows)
                rows = [r + [""] * (ncol - len(r)) for r in rows]
                self.tbl_idx += 1
                if pending_caption:
                    self.add_caption("表 %d-%d　%s" % (self.chapter, self.tbl_idx, pending_caption))
                    pending_caption = None
                else:
                    self.add_caption("表 %d-%d" % (self.chapter, self.tbl_idx))
                add_table(self.doc, rows, widths=table_width_override(rows))
                # spacing after table
                sp = self.doc.add_paragraph()
                sp.paragraph_format.space_before = Pt(0)
                sp.paragraph_format.space_after = Pt(0)
                sp.paragraph_format.line_spacing = 1.0
                r = sp.add_run("")
                set_run_font(r, size=6)
                continue

            if line.startswith("- "):
                p = self.doc.add_paragraph(style='List Bullet')
                p.paragraph_format.space_after = Pt(3)
                p.paragraph_format.left_indent = Cm(0.95)
                p.paragraph_format.first_line_indent = Cm(-0.35)
                p.paragraph_format.line_spacing = 1.4
                add_inline(p, line[2:])
                i += 1
                continue

            m = re.match(r'^(\d+)\.\s+(.*)$', line)
            if m:
                p = self.doc.add_paragraph()
                p.paragraph_format.left_indent = Cm(0.95)
                p.paragraph_format.first_line_indent = Cm(-0.6)
                p.paragraph_format.space_after = Pt(3)
                p.paragraph_format.line_spacing = 1.45
                r = p.add_run(m.group(1) + ".　")
                set_run_font(r, size=10.5, color=DARK)
                add_inline(p, m.group(2))
                i += 1
                continue

            if line.startswith("> "):
                p = self.doc.add_paragraph()
                p.paragraph_format.left_indent = Cm(0.5)
                p.paragraph_format.right_indent = Cm(0.3)
                p.paragraph_format.space_before = Pt(4)
                p.paragraph_format.space_after = Pt(6)
                p.paragraph_format.line_spacing = 1.35
                add_inline(p, line[2:], size=10)
                shade(p._p.get_or_add_pPr(), 'EEF3FA')
                p_border(p, 'left', '1F4E79', 14, 6)
                i += 1
                continue

            # normal paragraph
            p = self.doc.add_paragraph()
            p.paragraph_format.first_line_indent = Pt(21)
            p.paragraph_format.space_after = Pt(4)
            add_inline(p, line)
            i += 1


def main():
    doc = Document()
    setup_styles(doc)
    sec = doc.sections[0]
    page_setup(sec)

    build_cover(doc)
    build_front_matter(doc)

    # body section
    body = doc.add_section(WD_SECTION.NEW_PAGE)
    page_setup(body)
    restart_numbering(body)
    build_header_footer(body, "警院 WeChat 全生态 · 自学平台软件需求规格说明书")

    # blank header/footer for cover section
    sec.header.is_linked_to_previous = False
    sec.footer.is_linked_to_previous = False

    r = Renderer(doc)
    for f in ["p1.md", "p2.md", "p3.md", "p4.md", "p5.md", "p6.md", "p7.md"]:
        path = os.path.join(DOCS, f)
        with open(path, encoding="utf-8") as fh:
            r.render(fh.readlines())

    cp = doc.core_properties
    cp.title = TITLE
    cp.subject = "警院WeChat全生态 自学平台"
    cp.author = "产品组"
    cp.category = "软件需求规格说明书"
    cp.comments = "依据《五平台前端与功能联动约束规范V1.0》编制"

    doc.save(OUT)
    print("saved:", OUT)
    print("paragraphs:", len(doc.paragraphs), "tables:", len(doc.tables))


if __name__ == "__main__":
    main()
