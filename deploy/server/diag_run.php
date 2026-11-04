<?php
// 诊断包装：以非 root 身份运行入口，捕获致命错误
register_shutdown_function(function () {
    $e = error_get_last();
    $s = 'LAST_ERROR: ' . ($e ? json_encode($e, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : 'none') . PHP_EOL;
    $s .= 'OB_LEVEL: ' . ob_get_level() . PHP_EOL;
    $s .= 'MEM: ' . round(memory_get_peak_usage(true) / 1048576) . 'MB' . PHP_EOL;
    @file_put_contents('/tmp/diag.out', $s);
});
chdir('/www/ctc/public');
require '/www/ctc/public/index.php';
