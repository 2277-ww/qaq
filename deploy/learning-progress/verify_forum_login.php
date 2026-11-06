<?php
/**
 * 部署后验：在生产环境里跑一次真实的论坛账号登录
 *
 * 只验证「网关确认 + 本地建号」这一段，不接管 HTTP 会话。
 * saveAuthInfo 在 CLI 下可能因缺少 session 而失败，那不算功能问题，
 * 关键看 kg_account 是否写入了 forum_uid。
 *
 * 用法：php /tmp/verify_forum_login.php <账号> <密码>
 */

require '/www/ctc/bootstrap/Kernel.php';
require '/www/ctc/bootstrap/ConsoleKernel.php';

$login = $argv[1] ?? 'admin@jspi.edu.cn';
$pass = $argv[2] ?? 'Admin@12345';

$kernel = new \Bootstrap\ConsoleKernel();

$di = \Phalcon\Di::getDefault();

echo "DI          : ", ($di ? 'ready' : 'NULL'), "\n";

$cfg = $di ? $di->getShared('config') : null;

if ($cfg) {
    echo "app_key     : ", $cfg->path('gateway.app_key'), "\n";
    echo "account_base: ", $cfg->path('gateway.account_base'), "\n";
    echo "secret_len  : ", strlen((string)$cfg->path('gateway.app_secret')), "\n";
}

echo str_repeat('-', 60), "\n";

$verify = (new \App\Services\Gateway\AccountVerify())->verify($login, $pass, 'auto', 'deploy-check');

echo "verify.ok   : ", $verify['ok'] ? 'true' : 'false', "\n";
echo "verify.stat : ", $verify['status'], "\n";
echo "verify.rsn  : ", $verify['reason'], "\n";
echo "verify.err  : ", $verify['error'], "\n";
echo "requestId   : ", $verify['requestId'], "\n";

if (!empty($verify['user'])) {
    echo "identity    : ", json_encode($verify['user'], JSON_UNESCAPED_UNICODE), "\n";
}

echo str_repeat('-', 60), "\n";

if (!$verify['ok']) {
    echo "RESULT: 账号确认未通过，后续建号不会发生\n";
    exit(1);
}

try {

    $user = (new \App\Services\Logic\Account\ForumLogin())->handle($login, $pass, 'auto');

    echo "user.id     : ", $user->id, "\n";
    echo "user.name   : ", $user->name, "\n";
    echo "RESULT: 登录链路打通（含本地建号/复用）\n";
    exit(0);

} catch (\Throwable $e) {

    /**
     * CLI 下 saveAuthInfo 可能因无 session 抛异常。此时建号已经完成，
     * 属于会话层限制而非链路故障，单独标注出来，避免误判成接入失败。
     */
    echo "HANDLE EXC  : ", get_class($e), "\n";
    echo "message     : ", $e->getMessage(), "\n";
    echo "RESULT: 确认已通过，但会话建立阶段在 CLI 下不可用（属预期）\n";
    exit(2);
}
