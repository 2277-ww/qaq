#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build the SRS .docx from markdown sources."""
import os, re, glob
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING, WD_TAB_ALIGNMENT
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.enum.text import WD_BREAK
from PIL import Image as PILImage

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(BASE, "docs")
FIGS = os.path.join(BASE, "docs", "figs")
OUT = os.path.join(BASE, "自学平台软件需求规格说明书_V1.0.docx")

NAVY = RGBColor(0x1F, 0x38, 0x64)
DARK = RGBColor(0x26, 0x26, 0x26)
GRAY = RGBColor(0x59, 0x59, 0x59)
ACCENT = RGBColor(0x1F, 0x4E, 0x79)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

BODY_CN = "宋体"
HEAD_CN = "微软雅黑"
LATIN = "Times New Roman"

CONTENT_W = Cm(15.6)
TBL_W = Cm(15.4)


# ---------- low level helpers ----------

def set_run_font(run, cn=BODY_CN, latin=LATIN, size=10.5, bold=False, color=DARK, italic=False):
    run.font.name = latin
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic
    run.font.color.rgb = color
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:ascii'), latin)
    rFonts.set(qn('w:hAnsi'), latin)
    rFonts.set(qn('w:eastAsia'), cn)


def shade(element_pr, color):
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), color)
    element_pr.append(shd)


def p_border(paragraph, edge='bottom', color='1F3864', sz=8, space=4):
    pPr = paragraph._p.get_or_add_pPr()
    pBdr = pPr.find(qn('w:pBdr'))
    if pBdr is None:
        pBdr = OxmlElement('w:pBdr')
        pPr.append(pBdr)
    el = OxmlElement('w:%s' % edge)
    el.set(qn('w:val'), 'single')
    el.set(qn('w:sz'), str(sz))
    el.set(qn('w:space'), str(space))
    el.set(qn('w:color'), color)
    pBdr.append(el)


def add_field(paragraph, instr, placeholder="", size=9, color=GRAY):
    def _run():
        r = paragraph.add_run()
        set_run_font(r, size=size, color=color)
        return r
    r1 = _run()
    fc = OxmlElement('w:fldChar'); fc.set(qn('w:fldCharType'), 'begin'); r1._r.append(fc)
    r2 = _run()
    it = OxmlElement('w:instrText'); it.set(qn('xml:space'), 'preserve'); it.text = instr
    r2._r.append(it)
    r3 = _run()
    fc2 = OxmlElement('w:fldChar'); fc2.set(qn('w:fldCharType'), 'separate'); r3._r.append(fc2)
    r4 = _run()
    t = OxmlElement('w:t'); t.text = placeholder; r4._r.append(t)
    r5 = _run()
    fc3 = OxmlElement('w:fldChar'); fc3.set(qn('w:fldCharType'), 'end'); r5._r.append(fc3)


def add_toc_field(paragraph):
    r1 = paragraph.add_run(); set_run_font(r1, size=10)
    fc = OxmlElement('w:fldChar')
    fc.set(qn('w:fldCharType'), 'begin')
    fc.set(qn('w:dirty'), 'true')
    r1._r.append(fc)
    r2 = paragraph.add_run(); set_run_font(r2, size=10)
    it = OxmlElement('w:instrText'); it.set(qn('xml:space'), 'preserve')
    it.text = 'TOC \\o "1-3" \\h \\z \\u'
    r2._r.append(it)
    r3 = paragraph.add_run(); set_run_font(r3, size=10)
    fc2 = OxmlElement('w:fldChar'); fc2.set(qn('w:fldCharType'), 'separate'); r3._r.append(fc2)
    r4 = paragraph.add_run("（在本处右键选择“更新域”即生成目录）")
    set_run_font(r4, size=9, color=GRAY)
    r5 = paragraph.add_run(); set_run_font(r5, size=10)
    fc3 = OxmlElement('w:fldChar'); fc3.set(qn('w:fldCharType'), 'end'); r5._r.append(fc3)


# ---------- inline markup ----------

def add_inline(paragraph, text, size=10.5, color=DARK, bold=False, cn=BODY_CN):
    tokens = re.split(r'(\*\*.+?\*\*|`.+?`)', text)
    for tok in tokens:
        if not tok:
            continue
        if tok.startswith('**') and tok.endswith('**') and len(tok) > 4:
            r = paragraph.add_run(tok[2:-2])
            set_run_font(r, cn=cn, size=size, bold=True, color=color)
        elif tok.startswith('`') and tok.endswith('`') and len(tok) > 2:
            r = paragraph.add_run(tok[1:-1])
            set_run_font(r, cn=cn, latin="Consolas", size=size - 0.5, color=color)
        else:
            r = paragraph.add_run(tok)
            set_run_font(r, cn=cn, size=size, bold=bold, color=color)


# ---------- tables ----------

def _eff_len(s):
    s = re.sub(r'\*\*|`|<br>', '', s)
    n = 0
    for ch in s:
        n += 2 if ord(ch) > 0x2E80 else 1
    return n


def style_table(table, header_rows=1):
    tbl = table._tbl
    tblPr = tbl.tblPr
    # borders
    borders = OxmlElement('w:tblBorders')
    for edge in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        el = OxmlElement('w:%s' % edge)
        el.set(qn('w:val'), 'single')
        el.set(qn('w:sz'), '4')
        el.set(qn('w:space'), '0')
        el.set(qn('w:color'), 'BFBFBF')
        borders.append(el)
    tblPr.append(borders)
    # cell margins
    mar = OxmlElement('w:tblCellMar')
    for edge, w in (('top', 40), ('left', 80), ('bottom', 40), ('right', 80)):
        el = OxmlElement('w:%s' % edge)
        el.set(qn('w:w'), str(w))
        el.set(qn('w:type'), 'dxa')
        mar.append(el)
    tblPr.append(mar)
    layout = OxmlElement('w:tblLayout')
    layout.set(qn('w:type'), 'fixed')
    tblPr.append(layout)


def set_col_widths(table, widths):
    for row in table.rows:
        for i, cell in enumerate(row.cells):
            if i < len(widths):
                cell.width = widths[i]


def fill_cell(cell, text, bold=False, size=9, color=DARK, align=WD_ALIGN_PARAGRAPH.LEFT, cn=BODY_CN):
    cell.text = ""
    p = cell.paragraphs[0]
    p.alignment = align
    pf = p.paragraph_format
    pf.space_before = Pt(0.5)
    pf.space_after = Pt(0.5)
    pf.line_spacing = 1.15
    parts = text.split('<br>')
    for i, part in enumerate(parts):
        if i > 0:
            p.add_run().add_break()
        add_inline(p, part, size=size, color=color, bold=bold, cn=cn)


def add_table(doc, rows, widths=None, header=True):
    ncol = len(rows[0])
    table = doc.add_table(rows=len(rows), cols=ncol)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    style_table(table)
    # widths
    if widths is None:
        weights = []
        for c in range(ncol):
            mx = max(_eff_len(r[c]) for r in rows)
            weights.append(min(max(mx, 4), 46))
        total = sum(weights)
        widths = [Emu(int(TBL_W * (w / total))) for w in weights]
    set_col_widths(table, widths)
    for ri, row in enumerate(rows):
        tr = table.rows[ri]
        trPr = tr._tr.get_or_add_trPr()
        cant = OxmlElement('w:cantSplit'); trPr.append(cant)
        if ri < (1 if header else 0):
            th = OxmlElement('w:tblHeader'); trPr.append(th)
        for ci, val in enumerate(row):
            cell = tr.cells[ci]
            if ri < (1 if header else 0):
                fill_cell(cell, val, bold=True, size=9, color=WHITE)
                for p in cell.paragraphs:
                    shade(cell._tc.get_or_add_tcPr(), '1F3864')
            else:
                fill_cell(cell, val, bold=False, size=9, color=DARK)
                if (ri % 2) == 0:
                    shade(cell._tc.get_or_add_tcPr(), 'F4F7FB')
    return table


# ---------- document setup ----------

def setup_styles(doc):
    st = doc.styles['Normal']
    st.font.name = LATIN
    st.font.size = Pt(10.5)
    st.font.color.rgb = DARK
    rPr = st.element.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts'); rPr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), BODY_CN)
    pf = st.paragraph_format
    pf.line_spacing = 1.45
    pf.space_before = Pt(0)
    pf.space_after = Pt(3)

    specs = {
        'Heading 1': (17, True, 0, 14, NAVY),
        'Heading 2': (13.5, True, 16, 8, NAVY),
        'Heading 3': (11.5, True, 12, 5, ACCENT),
        'Heading 4': (11, True, 11, 4, ACCENT),
    }
    for name, (size, bold, sb, sa, color) in specs.items():
        s = doc.styles[name]
        s.font.name = LATIN
        s.font.size = Pt(size)
        s.font.bold = bold
        s.font.color.rgb = color
        rf = s.element.get_or_add_rPr()
        f = rf.find(qn('w:rFonts'))
        if f is None:
            f = OxmlElement('w:rFonts'); rf.append(f)
        f.set(qn('w:eastAsia'), HEAD_CN)
        f.set(qn('w:ascii'), HEAD_CN)
        f.set(qn('w:hAnsi'), HEAD_CN)
        s.paragraph_format.space_before = Pt(sb)
        s.paragraph_format.space_after = Pt(sa)
        s.paragraph_format.keep_with_next = True
        s.paragraph_format.line_spacing = 1.2

    doc.styles['Heading 1'].paragraph_format.page_break_before = True


def page_setup(section):
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(2.5)
    section.bottom_margin = Cm(2.4)
    section.left_margin = Cm(2.7)
    section.right_margin = Cm(2.7)
    section.header_distance = Cm(1.4)
    section.footer_distance = Cm(1.3)


def build_header_footer(section, title_text):
    section.header.is_linked_to_previous = False
    hp = section.header.paragraphs[0]
    hp.text = ""
    hp.paragraph_format.space_after = Pt(2)
    # tab stops: right aligned at content width
    tabs = hp.paragraph_format.tab_stops
    tabs.add_tab_stop(CONTENT_W, WD_TAB_ALIGNMENT.RIGHT)
    r = hp.add_run(title_text)
    set_run_font(r, cn=HEAD_CN, size=8.5, color=GRAY)
    r2 = hp.add_run("\tV1.0")
    set_run_font(r2, cn=HEAD_CN, size=8.5, color=GRAY)
    p_border(hp, 'bottom', 'BFBFBF', 4, 2)

    section.footer.is_linked_to_previous = False
    fp = section.footer.paragraphs[0]
    fp.text = ""
    fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = fp.add_run("第 ")
    set_run_font(r, size=9, color=GRAY)
    add_field(fp, "PAGE", "1")
    r = fp.add_run(" 页 / 共 ")
    set_run_font(r, size=9, color=GRAY)
    add_field(fp, "SECTIONPAGES", "1")
    r = fp.add_run(" 页")
    set_run_font(r, size=9, color=GRAY)


def restart_numbering(section):
    sectPr = section._sectPr
    pg = OxmlElement('w:pgNumType')
    pg.set(qn('w:start'), '1')
    sectPr.append(pg)
