<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Http\Home\Services;

use App\Exceptions\BadRequest as BadRequestException;
use App\Repos\User as UserRepo;
use App\Services\Auth\Home as AuthService;
use App\Services\Gateway\LoginThrottle;
use App\Services\Logic\Account\ForumLogin as ForumLoginService;
use App\Services\Logic\Account\LoginFieldTrait as LoginFieldTrait;
use App\Services\Logic\Account\Register as RegisterService;
use App\Validators\Account as AccountValidator;

class Account extends Service
{

    use LoginFieldTrait;

    /**
     * @var AuthService
     */
    protected $auth;

    public function __construct()
    {
        $this->auth = $this->getDI()->get('auth');
    }

    public function register()
    {
        $service = new RegisterService();

        $account = $service->handle();

        $userRepo = new UserRepo();

        $user = $userRepo->findById($account->id);

        $this->auth->saveAuthInfo($user);

        $this->eventsManager->fire('Account:afterRegister', $this, $user);

        return $user;
    }

    public function loginByPassword()
    {
        $post = $this->request->getPost();

        $post = $this->handleLoginFields($post);

        $validator = new AccountValidator();

        $user = $validator->checkUserLogin($post['account'], $post['password']);

        $validator->checkIfAllowLogin($user);

        $this->auth->saveAuthInfo($user);

        $this->eventsManager->fire('Account:afterLogin', $this, $user);
    }

    public function loginByVerify()
    {
        $post = $this->request->getPost();

        $post = $this->handleLoginFields($post);

        $validator = new AccountValidator();

        $user = $validator->checkVerifyLogin($post['account'], $post['verify_code']);

        $validator->checkIfAllowLogin($user);

        $this->auth->saveAuthInfo($user);

        $this->eventsManager->fire('Account:afterLogin', $this, $user);
    }

    /**
     * 论坛账号登录
     *
     * 与本地密码登录走不同链路：本地只校验用户名格式与限流，真正的密码
     * 校验交给论坛（本平台不持有论坛密码，也不落库）。
     *
     * 限流维度取客户端 IP 而非账号名：账号名可以被任意枚举，按账号计数
     * 挡不住「换一个账号继续试」；按 IP 计数虽然能被代理绕过，但成本更高，
     * 且与网关侧 10 次/分/IP 的口径一致。
     */
    public function loginByForum()
    {
        $post = $this->request->getPost();

        $post = $this->handleLoginFields($post);

        $account = isset($post['account']) ? trim((string)$post['account']) : '';

        $password = isset($post['password']) ? (string)$post['password'] : '';

        $throttle = new LoginThrottle();

        $limit = (int)$this->getConfig()->path('gateway.account_login_limit', 10);

        $window = (int)$this->getConfig()->path('gateway.account_login_window', 60);

        $retryAfter = 0;

        $allowed = $throttle->allow(
            'forum_login',
            (string)$this->request->getClientAddress(),
            $limit,
            $window,
            $retryAfter
        );

        if (!$allowed) {

            $this->getLogger()->warning(sprintf(
                'Forum Login Throttled: ip=%s retryAfter=%d',
                (string)$this->request->getClientAddress(),
                $retryAfter
            ));

            throw new BadRequestException('account.forum_rate_limited');
        }

        return (new ForumLoginService())->handle($account, $password);
    }

    public function logout()
    {
        $user = $this->getLoginUser();

        $this->auth->clearAuthInfo();

        $this->eventsManager->fire('Account:afterLogout', $this, $user);
    }

}
