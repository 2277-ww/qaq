# -*- coding: utf-8 -*-
"""文本改写工具：保持原文件换行符与 BOM；重复执行安全（已有改动视为已应用）。"""
import os
import re

SKIPPED = []


class EditError(Exception):
    pass


class Doc(object):
    def __init__(self, path):
        self.path = path
        raw = open(path, 'rb').read()
        self.bom = raw.startswith(b'\xef\xbb\xbf')
        if self.bom:
            raw = raw[3:]
        self.crlf = b'\r\n' in raw
        self.text = raw.decode('utf-8').replace('\r\n', '\n')
        self.dirty = False

    def _skip(self, what):
        SKIPPED.append('%s -> %s' % (os.path.basename(self.path), what))

    def sub(self, old, new, count=1):
        found = self.text.count(old)
        if found == 0:
            self._skip('未匹配片段（按已应用跳过）：' + old.strip().split('\n')[0][:60])
            return self
        if found != count:
            raise EditError('%s: 预期 %d 处匹配，实际 %d 处\n%s' % (self.path, count, found, old[:200]))
        self.text = self.text.replace(old, new)
        self.dirty = True
        return self

    def resub(self, pattern, new, count=1, flags=0):
        matches = re.findall(pattern, self.text, flags)
        if not matches:
            self._skip('正则未命中（按已应用跳过）：' + pattern[:60])
            return self
        if len(matches) != count:
            raise EditError('%s: 正则预期 %d 处匹配，实际 %d 处\n%s' % (self.path, count, len(matches), pattern[:200]))
        self.text = re.sub(pattern, new, self.text, flags=flags)
        self.dirty = True
        return self

    def drop_method(self, name):
        pattern = r'\n    /\*\*(?:\n     \*[^\n]*)*\n     \*/\n    (?:public|protected|private) function ' + name + r'\([^)]*\)\n    \{\n(?:.*\n)*?    \}\n'
        if not re.search(pattern, self.text):
            return self.drop_plain_method(name)
        self.text = re.sub(pattern, '\n', self.text, count=1)
        self.dirty = True
        return self

    def drop_plain_method(self, name):
        pattern = r'\n    (?:public|protected|private) function ' + name + r'\([^)]*\)\n    \{\n(?:.*\n)*?    \}\n'
        if not re.search(pattern, self.text):
            self._skip('未找到方法（按已删除跳过）：' + name)
            return self
        self.text = re.sub(pattern, '\n', self.text, count=1)
        self.dirty = True
        return self

    def drop_macro(self, name):
        pattern = r'\{%-? macro ' + name + r'\([^)]*\) %\}.*?\{%-? endmacro %\}\n\n?'
        if not re.search(pattern, self.text, re.S):
            self._skip('未找到宏（按已删除跳过）：' + name)
            return self
        self.text = re.sub(pattern, '', self.text, count=1, flags=re.S)
        self.dirty = True
        return self

    def save(self):
        if not self.dirty:
            return
        out = self.text.replace('\n', '\r\n') if self.crlf else self.text
        data = out.encode('utf-8')
        if self.bom:
            data = b'\xef\xbb\xbf' + data
        with open(self.path, 'wb') as fh:
            fh.write(data)


def edit(path, ops):
    doc = Doc(path)
    for op in ops:
        if callable(op):
            op(doc)
        else:
            doc.sub(*op)
    doc.save()
    return doc


def remove(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, _, files in os.walk(p, topdown=False):
                for f in files:
                    os.remove(os.path.join(root, f))
                os.rmdir(root)
        elif os.path.exists(p):
            os.remove(p)
