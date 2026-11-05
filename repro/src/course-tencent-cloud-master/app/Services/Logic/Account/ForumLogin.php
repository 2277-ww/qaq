<?php
/**
 * 论坛账号登录
 *
 * 用警院论坛账号确认结果建立**本平台自己的会话**，论坛账号只是身份来源，
 * 本平台不持有论坛 token，也不保存论坛密码。
 *
 * ── 三个设计决定 ──────────────────────────────────────────────────────
 *
 * 1) 首次登录自动建号。统一身份的诉求是「一个论坛账号登录所有平台」，
 *    要求学生先在本平台注册一次才能用论坛账号登录，等于把门槛又加回来。
 *
 * 2) 自动建的号**没有可用密码**。写入的是 32 字节随机数的哈希，不是空串，
 *    也不是可预测值：本平台密码校验是 md5(md5(pwd).md5(salt))，若存空串，
 *    哈希值对所有同类账号都相同，一旦被知道就等于这些账号有同一个「密码」。
 *    存随机值则任何输入都匹配不上，本地密码登录对这些账号恒为失败。
 *
 * 3) 论坛角色**不映射到 admin_role**。论坛 admin 只在本平台当普通学员：
 *    两个平台的「管理员」是两套独立概念，自动提权会把论坛的管理边界
 *    悄悄延伸到本平台后台。teacher 映射到 edu_role 是安全的，它只影响
 *    教学内容展示，不涉及后台权限。
 */

namespace App\Services\Logic\Account;

use App\Exceptions\BadRequest as BadRequestException;
use App\Exceptions\ServiceUnavailable as ServiceUnavailableException;
use App\Library\Utils\Password as PasswordUtil;
use App\Models\Account as AccountModel;
use App\Models\User as UserModel;
use App\Repos\Account as AccountRepo;
use App\Repos\User as UserRepo;
use App\Services\Auth\Home as AuthService;
use App\Services\Gateway\AccountVerify;
use App\Services\Logic\Service as LogicService;
use App\Validators\Account as AccountValidator;

class ForumLogin extends LogicService
{

    /**
     * 调用方标识，仅用于论坛侧审计
     */
    const CLIENT_ID = 'learning-web';

    /**
     * kg_user.name 列宽（varchar 30）
     */
    const NAME_MAX = 30;

    /**
     * 属于「用户输入错误」的失败原因，其余一律视为链路问题
     */
    const CREDENTIAL_REASONS = ['invalid_credentials'];

    /**
     * @var AuthService
     */
    protected $auth;

    public function __construct()
    {
        $this->auth = $this->getDI()->get('auth');
    }

    /**
     * @param string $login 论坛用户名或邮箱
     * @param string $password 明文密码，用完即弃
     * @param string $loginType auto / username / email
     * @return UserModel
     */
    public function handle($login, $password, $loginType = 'auto')
    {
        $verify = (new AccountVerify())->verify($login, $password, $loginType, self::CLIENT_ID);

        if (!$verify['ok']) {
            $this->reject($login, $verify);
        }

        $user = $this->resolve($verify['user'], $verify['requestId']);

        $this->auth->saveAuthInfo($user);

        $this->eventsManager->fire('Account:afterLogin', $this, $user);

        return $user;
    }

    /**
     * 按论坛主键找本地账号，没有则建
     *
     * @param array $identity
     * @param string $requestId
     * @return UserModel
     */
    protected function resolve(array $identity, $requestId)
    {
        $forumUid = (int)$identity['forumUid'];

        if ($forumUid <= 0) {

            /**
             * 论坛返回 confirmed=true 却没给 user_id，属于契约异常。
             * 此时不能建号——没有主键的账号下次登录会被重复创建。
             */
            $this->getLogger()->error('Forum Account Identity Broken: ' . kg_json_encode([
                'username' => $identity['username'],
                'requestId' => $requestId,
            ]));

            throw new ServiceUnavailableException('account.forum_unavailable');
        }

        $accountRepo = new AccountRepo();

        $account = $accountRepo->findByForumUid($forumUid);

        if (!$account) {
            $account = $this->create($identity, $forumUid);
        }

        if ((int)$account->deleted === 1) {
            throw new BadRequestException('user.not_found');
        }

        $user = (new UserRepo())->findById($account->id);

        if (!$user) {
            throw new BadRequestException('user.not_found');
        }

        /**
         * 复用平台既有的登录准入校验，避免两处各写一套锁定判定导致口径不一致。
         * 论坛侧认为可用、本平台侧已被锁定的账号，应以后者为准。
         */
        (new AccountValidator())->checkIfAllowLogin($user);

        return $user;
    }

    /**
     * 首次登录建号
     *
     * @param array $identity
     * @param int $forumUid
     * @return AccountModel
     */
    protected function create(array $identity, $forumUid)
    {
        $salt = PasswordUtil::salt();

        $account = new AccountModel();

        $account->forum_uid = $forumUid;

        $account->forum_name = kg_substr((string)$identity['username'], 0, 64, '');

        /**
         * 邮箱与手机留空：kg_account 上二者是普通索引，空串可以共存。
         * 论坛返回的邮箱是掩码（a***@jspi.edu.cn），不能当真实邮箱写入——
         * 一旦写入，用户之后想绑定自己的邮箱会撞「邮箱被占用」。
         */
        $account->email = '';

        $account->phone = '';

        $account->salt = $salt;

        /**
         * 32 字节随机数，不可预测也不可复用；本地密码登录对这些账号恒失败。
         */
        $account->password = PasswordUtil::hash(bin2hex(random_bytes(32)), $salt);

        try {

            $this->db->begin();

            /**
             * afterCreate 会自动建立 kg_user 与 kg_user_balance，
             * 建号逻辑集中在 Account 模型里，这里不重复实现。
             */
            $account->create();

            $this->db->commit();

        } catch (\Exception $e) {

            $this->db->rollback();

            /**
             * 同一账号并发首次登录会撞 forum_uid 唯一索引。
             * 这不是错误，回查即可——另一个请求已经建好了。
             */
            $existing = (new AccountRepo())->findByForumUid($forumUid);

            if ($existing) return $existing;

            $this->getLogger()->error('Forum Account Create Exception: ' . kg_json_encode([
                'forumUid' => $forumUid,
                'message' => $e->getMessage(),
            ]));

            throw new ServiceUnavailableException('account.forum_unavailable');
        }

        $this->fillProfile((int)$account->id, $identity);

        return $account;
    }

    /**
     * 用论坛信息补全本地资料
     *
     * 默认名是 user_{id}，对用户没有辨识度，换成论坛昵称或用户名。
     *
     * @param int $userId
     * @param array $identity
     * @return void
     */
    protected function fillProfile($userId, array $identity)
    {
        $user = (new UserRepo())->findById($userId);

        if (!$user) return;

        $name = trim((string)$identity['displayName']);

        if ($name === '') $name = trim((string)$identity['username']);

        if ($name === '') $name = 'user_' . $userId;

        $user->name = kg_substr($name, 0, self::NAME_MAX, '');

        /**
         * 只提升到讲师，不做管理员映射。admin 落库后仍是 edu_role=1、admin_role=0，
         * 与新建普通用户完全一致。
         */
        if ($identity['role'] === 'teacher') {
            $user->edu_role = UserModel::EDU_ROLE_TEACHER;
        }

        $user->update();

        $this->getLogger()->info('Forum Account Bound: ' . kg_json_encode([
            'userId' => $userId,
            'forumUid' => $identity['forumUid'],
            'role' => $identity['role'],
            'accountSource' => $identity['accountSource'],
        ]));
    }

    /**
     * 失败分流
     *
     * @param string $login
     * @param array $verify
     * @return void
     * @throws BadRequestException|ServiceUnavailableException
     */
    protected function reject($login, array $verify)
    {
        /**
         * 这里只记 login 与错误码，绝不记 password。
         * 论坛侧审计同样不记密码，本平台若在此处打出来，等于开了明文旁路。
         */
        $this->getLogger()->warning('Forum Account Verify Failed: ' . kg_json_encode([
            'login' => $login,
            'status' => $verify['status'],
            'reason' => $verify['reason'],
            'error' => $verify['error'],
            'requestId' => $verify['requestId'],
        ]));

        $reason = (string)$verify['reason'];

        if (in_array($reason, self::CREDENTIAL_REASONS, true)) {

            /**
             * 账号不存在与密码错误使用同一提示，与论坛的防枚举口径保持一致。
             */
            throw new BadRequestException('account.forum_login_failed');
        }

        if ($reason === 'account_unavailable') {
            throw new BadRequestException('account.forum_account_unavailable');
        }

        if ($reason === 'invalid_params') {
            throw new BadRequestException('account.forum_invalid_params');
        }

        if ($reason === 'not_configured') {
            throw new ServiceUnavailableException('account.forum_not_configured');
        }

        /**
         * 其余全是链路或配置问题（签名、AppKey、路由、限流、上游不可达），
         * 与用户输入无关，不能提示「密码错误」把用户引到错误方向。
         */
        throw new ServiceUnavailableException('account.forum_unavailable');
    }

}
