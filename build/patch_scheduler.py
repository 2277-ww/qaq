import re

p = '/www/ctc/scheduler.php'
s = open(p, 'rb').read().decode('utf-8')
orig = s

s = s.replace("$bin = '/usr/local/bin/php';", "$bin = '/usr/bin/php';")

tasks = ['sync_course_index', 'sync_article_index', 'sync_question_index']
for t in tasks:
    pat = re.compile(
        r"\$scheduler->php\(\$script, \$bin, \['--task' => '" + t +
        r"', '--action' => 'main'\]\)\s*\r?\n\s*->hourly\(\d+\);\r?\n"
    )
    repl = ("// [停用 " + t + "] 搜索已改为 MySQL LIKE，XunSearch 未部署，"
            "该任务会抛 Missing field of type ID\n")
    s, n = pat.subn(repl, s)
    if n == 0:
        print('WARN 未匹配:', t)

if s == orig:
    print('无改动')
else:
    open(p, 'wb').write(s.encode('utf-8'))
    print('已修改 scheduler.php')
