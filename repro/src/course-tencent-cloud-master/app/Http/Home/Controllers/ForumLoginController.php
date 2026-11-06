<?php
/**
 * 论坛账号登录（独立入口）
 *
 * 生产站点是裁剪版：首页没有登录/注册链接，/account/login 与 /account/register
 * 均为 404——整个账号模块的控制器与视图都被裁掉了。因此本控制器单独提供一页，
 * 不复用被删除的 account 视图，也不改动任何现有页面。
 *
 * 与「恢复完整账号模块」相比，这样做的差别是：只多一个登录入口，不把注册、
 * 找回密码等一整条链路一并放回线上。后者属于产品决策，不应由部署顺手带走。
 *
 * 凭据不出本平台：密码只经网关转给论坛做只读确认，本平台不保存、不落日志。
 *
 * 注意两处生产环境约定：
 * 1. 路由由注解扫描生成（config/routes.php 遍历 Controllers 目录后
 *    addModuleResource），@RoutePrefix 必须写在紧贴 class 的 docblock 里。
 *    放到 namespace 之前不会报错，但注解属于「文件级注释」，路由不会被注册。
 * 2. 基类 beforeExecuteRoute 对非安全请求强制校验 CSRF 与同源 Referer，
 *    白名单为空。原生表单用 csrf_token 隐藏字段走 postToken 分支。
 */

namespace App\Http\Home\Controllers;

use App\Library\Logger as AppLogger;
use App\Services\Gateway\AccountVerify;
use App\Services\Gateway\LoginThrottle;
use App\Services\Logic\Account\ForumLogin as ForumLoginService;

/**
 * @RoutePrefix("/account")
 */
class ForumLoginController extends Controller
{

    /**
     * 视图路径（与控制器名不同，必须显式 pick）
     */
    const VIEW = 'account/forum_login';

    /**
     * @Get("/forum-login", name="home.forum_login.show")
     */
    public function showAction()
    {
        return $this->renderForm();
    }

    /**
     * @Post("/forum/login", name="home.forum_login.submit")
     */
    public function submitAction()
    {
        $account = trim((string)$this->request->getPost('account'));

        $password = (string)$this->request->getPost('password');

        $config = $this->getDI()->getShared('config');

        $throttle = new LoginThrottle();

        $retryAfter = 0;

        /**
         * 按 IP 限流：账号名可被任意枚举，按账号计数挡不住「换一个账号继续试」。
         * 本平台在这里是论坛账号确认的代理入口，不限流等于把尝试成本转嫁给论坛。
         */
        $allowed = $throttle->allow(
            'forum_login',
            (string)$this->request->getClientAddress(),
            (int)$config->path('gateway.account_login_limit', 10),
            (int)$config->path('gateway.account_login_window', 60),
            $retryAfter
        );

        if (!$allowed) {

            $this->logEvent('warning', 'Forum Login Throttled', [
                'account' => $account,
                'retryAfter' => $retryAfter,
            ]);

            $this->view->setVar('error_message', sprintf('尝试次数过多，请 %d 秒后再试', $retryAfter));

            return $this->renderForm($account);
        }

        try {

            $user = (new ForumLoginService())->handle($account, $password, 'auto');

            $this->logEvent('info', 'Forum Login Succeeded', [
                'account' => $account,
                'userId' => (int)$user->id,
            ]);

        } catch (\Throwable $e) {

            /**
             * 异常 message 是错误键（如 account.forum_login_failed），
             * 需要翻成文案再给用户看，否则页面上会出现一串英文键名。
             */
            $this->logEvent('warning', 'Forum Login Rejected', [
                'account' => $account,
                'class' => get_class($e),
                'key' => $e->getMessage(),
                'file' => basename($e->getFile()),
                'line' => $e->getLine(),
            ]);

            $this->view->setVar('error_message', $this->messageOf($e));

            return $this->renderForm($account);
        }

        return $this->response->redirect(['for' => 'home.index']);
    }

    /**
     * 渲染登录表单
     *
     * @param string $account 回填的账号，避免用户输错密码后要重填
     * @return void
     */
    protected function renderForm($account = '')
    {
        $this->view->pick(self::VIEW);

        $this->seo->prependTitle('论坛账号登录');

        $this->view->setVar('forum_login_enabled', (new AccountVerify())->isEnabled());

        $this->view->setVar('posted_account', $account);
    }

    /**
     * 错误键 → 用户文案
     *
     * @param \Throwable $e
     * @return string
     */
    protected function messageOf(\Throwable $e)
    {
        $errors = require config_path('errors.php');

        $key = $e->getMessage();

        if (isset($errors[$key])) return $errors[$key];

        /**
         * 未收录的键不把原文抛给用户，只给一句通用提示。
         * 具体错误键已由 logEvent 记入日志，这里不重复记。
         */
        return '登录失败，请稍后重试';
    }

    /**
     * 登录事件日志（gateway 通道）
     *
     * 只记判定依据：账号名、错误键、位置、请求路径与来源 IP。
     * 绝不记 password、请求体或任何密钥——日志的留存与访问面远大于配置文件。
     *
     * 整体包 try/catch：日志故障不能改变登录结论，否则等于用一个日志问题
     * 把「拒绝」变成 500，或把「成功」变成失败。
     *
     * @param string $level info|warning
     * @param string $event
     * @param array $data
     * @return void
     */
    protected function logEvent($level, $event, array $data)
    {
        try {

            $data['path'] = (string)parse_url((string)$this->request->getURI(), PHP_URL_PATH);

            $data['method'] = (string)$this->request->getMethod();

            $data['ip'] = (string)$this->request->getClientAddress();

            $logger = (new AppLogger())->getInstance('gateway');

            $logger->$level($event . ': ' . kg_json_encode($data));

        } catch (\Throwable $e) {
            // 日志失败不改变业务结论
        }
    }

}
