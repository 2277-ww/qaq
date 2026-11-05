# -*- coding: utf-8 -*-
"""阶段四：移除「收货地址」。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

E.edit(p('app/Http/Home/Controllers/UserConsoleController.php'), [
    ('use App\\Services\\Logic\\User\\Console\\ContactInfo as ContactInfoService;\n', ''),
    ('use App\\Services\\Logic\\User\\Console\\ContactUpdate as ContactUpdateService;\n', ''),
    lambda d: d.drop_method('contactAction'),
    lambda d: d.drop_method('updateContactAction'),
])

E.edit(p('app/Http/Home/Views/user/console/menu.volt'), [
    ("""            <li><a href="{{ url({'for':'home.uc.contact'}) }}">收货地址</a></li>
""", ''),
])

E.edit(p('app/Repos/User.php'), [
    ('use App\\Models\\UserContact as UserContactModel;\n', ''),
    lambda d: d.drop_method('findUserContact'),
])

def drop(rel):
    full = p(rel)
    if os.path.exists(full):
        E.remove([full])
    else:
        print('已不存在，跳过：', rel)

for rel in [
    'app/Http/Home/Views/user/console/contact.volt',
    'app/Services/Logic/User/Console/ContactInfo.php',
    'app/Services/Logic/User/Console/ContactUpdate.php',
    'app/Models/UserContact.php',
    'app/Validators/UserContact.php',
    'public/static/home/js/user.console.contact.js',
]:
    drop(rel)

print('阶段四完成')
