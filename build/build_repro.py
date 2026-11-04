#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build the CTC reproduction guide .docx from markdown sources."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from docx import Document
from docx.shared import Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.enum.section import WD_SECTION

from docx_lib import (DOCS, GRAY, NAVY, DARK, set_run_font, p_border,
                      add_field, add_toc_field, add_inline, add_table,
                      setup_styles, page_setup, build_header_footer,
                      restart_numbering)
from build_main import Renderer, spacer, minor_title

TITLE = "酷瓜云课堂 本地复现说明"
DOC_NO = "REPRO-CTC-01"
VER = "V1.0"
DATE_CN = "2026 年 11 月"
DATE_ISO = "2026-11-03"
OUT_PATH = os.path.join(os.path.dirname(DOCS), "酷瓜云课堂_本地复现说明_V1.0.docx")


def build_cover(doc):
    spacer(doc, 54)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run("开源项目复现与验证系列")
    set_run_font(r, cn="微软雅黑", size=10.5, color=GRAY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("酷瓜云课堂")
    set_run_font(r, cn="微软雅黑", size=34, bold=True, color=NAVY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(40)
    r = p.add_run("本地复现说明")
    set_run_font(r, cn="微软雅黑", size=26, bold=True, color=NAVY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("Windows 原生环境 · 环境搭建 · 启动流程 · 核心功能验证")
    set_run_font(r, cn="微软雅黑", size=11, color=GRAY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(56)
    r = p.add_run("PHP 7.3.33 + Phalcon 3.4.5 + MySQL 5.7.38 + Redis 5.0.14")
    set_run_font(r, cn="微软雅黑", size=9.5, color=GRAY)

    # info block
    rows = [
        ["文档编号", DOC_NO, "版本", VER],
        ["复现对象", "酷瓜云课堂（Course Tencent Cloud）", "程序版本", "CTC 1.8.3"],
        ["运行环境", "Windows 11 / PHP 7.3 NTS / MySQL 5.7 / Redis 5.0", "协议", "GPL-2.0"],
        ["本地地址", "http://127.0.0.1:8000", "日期", DATE_ISO],
    ]
    add_table(doc, rows, widths=[Cm(2.4), Cm(6.4), Cm(2.2), Cm(4.4)])

    spacer(doc, 40)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(DATE_CN)
    set_run_font(r, cn="微软雅黑", size=11, color=NAVY)


def build_front_matter(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)

    minor_title(doc, "文 档 说 明")
    rows = [
        ["文档名称", "酷瓜云课堂本地复现说明", "文档编号", DOC_NO],
        ["版本号", VER, "文档状态", "已实测"],
        ["编写日期", DATE_ISO, "复现环境", "Windows 11 / x64"],
        ["读者对象", "负责搭建、验证与二次开发的技术人员", "前置知识", "PHP / MySQL / Composer 基础操作"],
        ["文档范围", "环境依赖、搭建步骤、启停脚本、功能验证、问题定位", "不包含", "生产部署、性能压测、腾讯云服务接入"],
        ["交付形态", "本文档 + 两个启停脚本 + 可运行的本地环境", "复现结论", "核心链路通过，详见第 5 章"],
    ]
    add_table(doc, rows, widths=[Cm(2.35), Cm(6.35), Cm(2.35), Cm(4.15)])

    spacer(doc, 4)
    minor_title(doc, "复 现 摘 要")
    summary = [
        ("结论", "在 Windows 上以 PHP 7.3 + Phalcon 3.4.5 + MySQL 5.7 + Redis 5.0 原生搭建，成功运行酷瓜云课堂 CTC 1.8.3，课程浏览、前台登录、后台管理三条主链路均通过验证。"),
        ("关键前提", "Phalcon 的 Windows DLL 必须与 PHP 的主次版本、线程安全模式、编译工具链三者完全一致；本项目只能用 PHP 7.3 NTS VC15 x64 搭配 phalcon 3.4.5-4250-nts。"),
        ("主要障碍", "共记录 12 个真实问题，集中在四类：Phalcon 的 Web 重写机制、PHP 7 的方法签名校验、Linux 专有接口缺失、进程托管与开机自启，详见第 6 章。"),
        ("成本与稳定性", "从零搭建约 40 分钟（依赖下载占大半），后续重启约 15 秒；连续启停 3 次、种子脚本重复执行，结果一致，流程可重复。"),
    ]
    for k, v in summary:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(1.5)
        p.paragraph_format.first_line_indent = Cm(-1.5)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.35
        r = p.add_run(k + "　")
        set_run_font(r, cn="微软雅黑", size=10.5, bold=True, color=NAVY)
        add_inline(p, v, size=10.5)

    spacer(doc, 2)
    minor_title(doc, "阅 读 指 引")
    guide = [
        ("第 1—2 章", "复现目标、验收标准与依赖矩阵。要判断“这套环境能不能用”，看这两章。"),
        ("第 3 章", "八步搭建流程，每步都有验证动作。照着做即可，不需要理解原理。"),
        ("第 4 章", "启停脚本与排障用的手工命令。日常使用只看这一章。"),
        ("第 5 章", "功能验证结果与界面证据，共 12 项检查、6 张实拍截图。"),
        ("第 6 章", "12 个问题的根因与修复，是本文档最有价值的部分，建议通读。"),
        ("第 7—8 章", "已知限制、稳定性结论与勾选式核对清单。"),
    ]
    for k, v in guide:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(1.6)
        p.paragraph_format.first_line_indent = Cm(-1.6)
        p.paragraph_format.space_after = Pt(3)
        r = p.add_run(k + "　")
        set_run_font(r, cn="微软雅黑", size=10.5, bold=True, color=NAVY)
        add_inline(p, v, size=10.5)

    toc_title = minor_title(doc, "目　　录")
    toc_title.paragraph_format.page_break_before = True
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    add_toc_field(p)


def load_md(path):
    """Read markdown, converting ``` fenced blocks into shaded block paragraphs."""
    out = []
    in_code = False
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            s = raw.rstrip("\n")
            if s.strip().startswith("```"):
                in_code = not in_code
                continue
            if in_code:
                out.append(("> " + s) if s.strip() else ">\n")
            else:
                out.append(raw)
    return out


def tune_toc_styles(doc):
    """Compact the TOC so 51 entries fit on two pages after the field is built."""
    spec = {1: (0.0, 10.5), 2: (0.7, 10.0), 3: (1.4, 9.5)}
    for lvl, (indent, size) in spec.items():
        name = "toc %d" % lvl
        try:
            st = doc.styles[name]
        except KeyError:
            continue
        pf = st.paragraph_format
        pf.space_before = Pt(0)
        pf.space_after = Pt(2)
        pf.line_spacing = 1.12
        pf.left_indent = Cm(indent)
        pf.right_indent = Cm(0.5)
        st.font.size = Pt(size)


def main():
    doc = Document()
    setup_styles(doc)
    tune_toc_styles(doc)
    sec = doc.sections[0]
    page_setup(sec)

    build_cover(doc)
    build_front_matter(doc)

    body = doc.add_section(WD_SECTION.NEW_PAGE)
    page_setup(body)
    restart_numbering(body)
    build_header_footer(body, "酷瓜云课堂 本地复现说明")

    sec.header.is_linked_to_previous = False
    sec.footer.is_linked_to_previous = False

    r = Renderer(doc)
    for f in ["repro_a.md", "repro_b.md"]:
        r.render(load_md(os.path.join(DOCS, f)))

    cp = doc.core_properties
    cp.title = TITLE
    cp.subject = "开源项目本地复现与功能验证"
    cp.author = "技术验证组"
    cp.category = "技术文档"
    cp.comments = "酷瓜云课堂 CTC 1.8.3 本地复现记录"

    doc.save(OUT_PATH)
    print("saved:", OUT_PATH)
    print("paragraphs:", len(doc.paragraphs), "tables:", len(doc.tables),
          "images:", len(doc.inline_shapes))


if __name__ == "__main__":
    main()
