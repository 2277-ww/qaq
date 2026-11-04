#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from docx import Document
from docx.shared import Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.enum.section import WD_SECTION

from docx_lib import (DOCS, NAVY, DARK, GRAY, ACCENT, HEAD_CN, WHITE,
                      set_run_font, add_table, setup_styles, page_setup,
                      build_header_footer, restart_numbering, p_border, add_toc_field)
import build_main
from build_main import Renderer, minor_title, spacer

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(BASE, "research")
OUT = os.path.join(BASE, "开源项目选型与界面比对报告_V1.0.docx")
build_main.FIGS = os.path.join(RES, "final")


def build_cover(doc):
    spacer(doc, 44)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("警院 WeChat 全生态 · 自学平台")
    set_run_font(r, cn=HEAD_CN, size=10.5, color=GRAY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(48)
    r = p.add_run("配套技术调研 · 依据《自学平台软件需求规格说明书 V1.0》")
    set_run_font(r, cn=HEAD_CN, size=9, color=GRAY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("开源项目选型")
    set_run_font(r, cn=HEAD_CN, size=34, bold=True, color=NAVY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(10)
    r = p.add_run("与 界 面 比 对 报 告")
    set_run_font(r, cn=HEAD_CN, size=26, bold=True, color=NAVY)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(10)
    r = p.add_run("Open-Source Project Benchmark & UI Comparison")
    set_run_font(r, cn=HEAD_CN, size=11, color=ACCENT)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(52)
    r = p.add_run("PlayEdu　·　酷瓜云课堂　·　Moodle")
    set_run_font(r, cn=HEAD_CN, size=13, bold=True, color=DARK)

    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(28)
    r = p.add_run("─" * 34)
    set_run_font(r, cn=HEAD_CN, size=9, color=WHITE.__class__(0xBF, 0xC7, 0xD6))

    for line in ("文档版本：V1.0　　　　文档编号：RS-SELFSTUDY-01",
                 "文档状态：评审稿　　　　密　　级：内部"):
        p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(6)
        r = p.add_run(line)
        set_run_font(r, cn=HEAD_CN, size=10.5, color=DARK)

    spacer(doc, 54)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("共 3 个项目 · 14 张界面截图 · 全部取自官方公开演示环境")
    set_run_font(r, cn=HEAD_CN, size=10, color=GRAY)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("2026 年 11 月")
    set_run_font(r, cn=HEAD_CN, size=11, color=NAVY)


def build_front(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    minor_title(doc, "文 档 信 息")
    rows = [
        ["文档名称", "开源项目选型与界面比对报告", "文档编号", "RS-SELFSTUDY-01"],
        ["版本号", "V1.0", "文档状态", "评审稿"],
        ["密　　级", "内部", "编写日期", "2026-11-03"],
        ["关联文档", "自学平台软件需求规格说明书 V1.0", "调研对象", "3 个开源在线学习系统"],
        ["读者对象", "产品、架构、前端与后端研发、测试、评审专家", "用途", "设计参考与需求修订依据"],
    ]
    add_table(doc, rows, widths=[Cm(2.35), Cm(6.35), Cm(2.35), Cm(4.15)])

    spacer(doc, 8)
    minor_title(doc, "结 论 摘 要")
    summary = [
        ("结论一", "不推荐以任何开源项目作为代码底座。三个项目均缺少本平台三项关键能力：发布审核状态机、跨平台公开接口与业务事件、论坛统一身份接入。"),
        ("结论二", "推荐 PlayEdu 作为设计主基线。其“课程—课时—进度”模型与需求文档第 6 章差异最小，前端同为 React 体系，迁移风险最低。"),
        ("结论三", "酷瓜云课堂用于补充微信端形态与“图文 + 点播”双课时表达；Moodle 仅用于参照活动完成模型与学生 × 活动进度矩阵。"),
        ("结论四", "比对发现 6 处可优化点，其中 3 处涉及接口或非功能指标，建议随 SRS 下一版评审（详见 6.3）。"),
    ]
    for k, v in summary:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(0.95)
        p.paragraph_format.first_line_indent = Cm(-0.95)
        p.paragraph_format.space_after = Pt(5)
        r = p.add_run(k + "　")
        set_run_font(r, cn=HEAD_CN, size=10.5, bold=True, color=NAVY)
        build_main.add_inline(p, v, size=10.5)

    spacer(doc, 8)
    minor_title(doc, "阅 读 指 引")
    guide = [
        ("第 1 章", "选型口径：硬性门槛、评估维度、候选池与排除理由。关心“为什么不选其他项目”的读者可看 1.4。"),
        ("第 2～4 章", "三个项目的逐一分析，统一按“概览—选择依据—需求对应关系—界面实录—特点—局限”组织，每章含 4～5 张截图。"),
        ("第 5 章", "横向对比：加权得分、关键差异对照、边界冲突清单。"),
        ("第 6 章", "结论：推荐组合、可借鉴与需自研的划分、对需求文档的 6 条修订建议、落地路线。"),
        ("第 7 章", "附录：截图采集环境与账号来源、参考链接，供复现与核验。"),
    ]
    for k, v in guide:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(0.95)
        p.paragraph_format.first_line_indent = Cm(-0.95)
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(k + "　")
        set_run_font(r, cn=HEAD_CN, size=10.5, bold=True, color=NAVY)
        build_main.add_inline(p, v, size=10.5)

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    minor_title(doc, "目　　录")
    p = doc.add_paragraph()
    add_toc_field(p)


def with_table_captions(lines):
    """Insert a [表] caption (current section title) before each table block lacking one."""
    out = []
    last_title = ""
    in_table = False
    for line in lines:
        line = line.rstrip("\n")
        s = line.strip()
        if not s:
            in_table = False
            out.append(line)
            continue
        if s.startswith("## "):
            last_title = s[3:].strip()
        elif s.startswith("### "):
            last_title = s[4:].strip()
        if s.startswith("|"):
            if not in_table:
                prev = out[-1].strip() if out else ""
                if not prev.startswith("[表]"):
                    title = re.sub(r"^\d+(\.\d+)*\s*", "", last_title)
                    out.append(f"[表] {title}")
                in_table = True
        else:
            in_table = False
        out.append(line)
    return out


def main():
    doc = Document()
    setup_styles(doc)
    sec = doc.sections[0]
    page_setup(sec)

    build_cover(doc)
    build_front(doc)

    body = doc.add_section(WD_SECTION.NEW_PAGE)
    page_setup(body)
    restart_numbering(body)
    build_header_footer(body, "自学平台 · 开源项目选型与界面比对报告")
    sec.header.is_linked_to_previous = False
    sec.footer.is_linked_to_previous = False

    r = Renderer(doc)
    for f in ["r1.md", "r2.md", "r3.md", "r4.md"]:
        with open(os.path.join(RES, f), encoding="utf-8") as fh:
            r.render(with_table_captions(fh.readlines()))

    cp = doc.core_properties
    cp.title = "开源项目选型与界面比对报告"
    cp.subject = "自学平台配套技术调研"
    cp.author = "产品组"
    doc.save(OUT)
    print("saved:", OUT, "tables:", len(doc.tables), "paras:", len(doc.paragraphs))


if __name__ == "__main__":
    main()
