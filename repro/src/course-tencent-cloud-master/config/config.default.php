<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

$config = [];

/**
 * 运行环境（dev|test|pro）
 */
$config['env'] = 'pro';

/**
 * 密钥
 */
$config['key'] = 'PUT-YOUR-APP-KEY-HERE';

/**
 * 所在时区
 */
$config['timezone'] = 'Asia/Shanghai';

/**
 * 日志级别
 */
$config['log']['level'] = Phalcon\Logger::INFO;

/**
 * 日志链路
 */
$config['log']['trace'] = false;

/**
 * 网站根地址，必须以"/"结尾
 */
$config['base_uri'] = '/';

/**
 * 静态资源根地址，必须以"/"结尾
 */
$config['static_base_uri'] = '/static/';

/**
 * 静态资源版本
 */
$config['static_version'] = '202004080830';

/**
 * 数据库主机名
 */
$config['db']['host'] = 'mysql';

/**
 * 数据库端口
 */
$config['db']['port'] = 3306;

/**
 * 数据库名称
 */
$config['db']['dbname'] = 'ctc';

/**
 * 数据库用户名
 */
$config['db']['username'] = 'ctc';

/**
 * 数据库密码
 */
$config['db']['password'] = '1qaz2wsx3edc';

/**
 * 数据库编码
 */
$config['db']['charset'] = 'utf8mb4';

/**
 * redis主机名
 */
$config['redis']['host'] = 'redis';

/**
 * redis端口号
 */
$config['redis']['port'] = 6379;

/**
 * redis库编号
 */
$config['redis']['index'] = 0;

/**
 * redis密码
 */
$config['redis']['auth'] = '1qaz2wsx3edc';

/**
 * 缓存有效期（秒）
 */
$config['cache']['lifetime'] = 24 * 3600;

/**
 * 会话有效期（秒）
 */
$config['session']['lifetime'] = 24 * 3600;

/**
 * 令牌有效期（秒）
 */
$config['token']['lifetime'] = 7 * 86400;

/**
 * 元数据有效期（秒）
 */
$config['metadata']['lifetime'] = 7 * 86400;

/**
 * 注解有效期（秒）
 */
$config['annotation']['lifetime'] = 7 * 86400;

/**
 * CsrfToken有效期（秒）
 */
$config['csrf_token']['lifetime'] = 86400;

/**
 * 允许跨域
 */
$config['cors']['enabled'] = true;

/**
 * 允许跨域域名(字符|数组)
 */
$config['cors']['allow_origin'] = '*';

/**
 * 允许跨域字段（string|array）
 */
$config['cors']['allow_headers'] = '*';

/**
 * 允许跨域方法
 */
$config['cors']['allow_methods'] = ['GET', 'POST', 'OPTIONS'];

/**
 * 客户端ping服务端间隔（秒）
 */
$config['websocket']['ping_interval'] = 30;

/**
 * 客户端连接地址（外部可访问的域名或ip），带端口号
 */
$config['websocket']['connect_address'] = 'your_domain.com:8282';

/**
 * gateway和worker注册地址，带端口号
 */
$config['websocket']['register_address'] = '127.0.0.1:1238';

/**
 * 资源监控: CPU负载（0.1-1.0）
 */
$config['server_monitor']['cpu'] = 0.8;

/**
 * 资源监控: 内存剩余占比（10-100）%
 */
$config['server_monitor']['memory'] = 10;

/**
 * 资源监控: 磁盘剩余占比（10-100）%
 */
$config['server_monitor']['disk'] = 20;

/**
 * 交易有效期（秒）
 */
$config['trade']['lifetime'] = 15 * 60;

/**
 * 统一网关
 *
 * base_uri: 网关入口根地址（如 https://api.jingyuan.edu.cn）。留空表示未接入网关，
 *           学习进度事件仍会入箱并标记为已投递（本地直连模式，用于复现环境演示）。
 * internal_sign_secret: 内部签名密钥，与网关约定；生产必须配置且不得入库。
 * verify_sign: 是否校验入站 X-Internal-Sign。生产必须为 true，复现环境可置 false 联调。
 * timestamp_skew: 入站时间戳允许偏移（秒）。
 */
$config['gateway']['base_uri'] = '';

$config['gateway']['app_code'] = 'learning';

$config['gateway']['internal_sign_secret'] = '';

$config['gateway']['verify_sign'] = false;

$config['gateway']['timestamp_skew'] = 300;

$config['gateway']['timeout'] = 5;

/**
 * 网关统一鉴权令牌
 * APISIX 若开启 jwt-auth / key-auth，服务态调用需带 Bearer 令牌；
 * 内网白名单放行的场景留空即可。
 */
$config['gateway']['access_token'] = '';

/**
 * 是否要求对端返回 JSON
 * true 时只有 { 或 [ 开头的 2xx 响应才算投递成功，用于挡住网关 catch-all
 * 路由返回的 HTML 默认页（状态码 200，内容不是业务响应）。
 */
$config['gateway']['expect_json'] = true;

/**
 * 网关 L2 应用凭据（服务态调用）
 *
 * app_key / app_secret 是网关入口鉴权，与 internal_sign_secret 那套七头内部
 * 签名不是同一把密钥。app_secret 从网关服务器 /etc/jingyuan-gateway/secrets.json
 * 的 app_keys 段取得，不得写进版本库；为空时指向网关的投递会直接失败并记录原因。
 */
$config['gateway']['app_key'] = 'jy-learning-svc';

$config['gateway']['app_secret'] = '';

/**
 * 考试平台对接
 *
 * push_path: 经网关投递学习进度的路径（由考试平台契约约定）。
 * user_prefix: 未接入 OIDC 前对外 userId 的占位前缀，接入后以 kg_identity_binding.sub 为准。
 * min_progress_delta: 进度增量上报的最小百分比差，低于该值合并到下一次。
 * retry_max: 投递失败最大重试次数，超过转死信。
 */
$config['exam']['enabled'] = true;

$config['exam']['push_path'] = '/api/v1/exam/learning/progress';

$config['exam']['user_prefix'] = 'usr_';

$config['exam']['min_progress_delta'] = 5;

$config['exam']['retry_max'] = 6;

/**
 * 跨平台对端（学习进度出口）
 *
 * 考试、实训、论坛共用同一套发件箱与网关出口，按对端配置路由。
 * events 白名单对应《统一身份与网关接入说明》8.1 的事件目录；
 * extensions / extension_path 用于本地扩展事件的隔离通道，默认关闭；
 * inbound / inbound_events 用于接收对端回传事件；
 * ack / pull / replay 为对端反向能力：投递回执、增量拉取、失败重放，默认只对考试平台开通。
 *
 * 入站鉴权（对端调我们）：
 * inbound_app_code: 对端自己的应用编码，入站靠它识别调用方，三个平台必须各不相同。
 * secret:           该对端的签名密钥，填上即自动升级为 HMAC 签名校验（auth_mode=auto）。
 * auth_mode:        auto|signature|token|none，none 仅用于联调，上线须落到 signature 或 token。
 * token:            token 模式的比对值（Authorization: Bearer 或 X-Api-Key）。
 * query:            是否允许该对端按学生查进度与准入判定。
 *
 * 出站鉴权（我们调对端）：access_token 覆盖全局 gateway.access_token，
 * headers 用于携带网关附加凭据（如 APISIX key-auth 的 X-API-Key）。
 */
$config['peers']['exam'] = [
    'enabled' => true,
    'name' => '考试平台',
    'base_uri' => '',
    'app_code' => 'learning',
    'push_path' => '/api/v1/exam/learning/progress',
    'events' => ['course.completed'],
    'extensions' => false,
    'extension_path' => '',
    'inbound' => true,
    'inbound_events' => ['exam.progress.ack'],
    'inbound_app_code' => 'exam',
    'secret' => '',
    'auth_mode' => 'auto',
    'token' => '',
    'query' => true,
    'access_token' => '',
    'headers' => [],
    'ack' => true,
    'pull' => true,
    'pull_limit' => 200,
    'replay' => true,
];

$config['peers']['training'] = [
    'enabled' => false,
    'name' => '实训平台',
    'base_uri' => '',
    'app_code' => 'learning',
    'push_path' => '/api/v1/training/learning/progress',
    'events' => ['course.completed'],
    'extensions' => false,
    'extension_path' => '',
    'inbound' => false,
    'inbound_events' => ['practice.submitted', 'practice.completed'],
];

/**
 * 论坛平台（8.138.246.181 五平台统一网关后的真实业务系统）
 *
 * push_path 必须落在网关 L2 路由内：/api/v1/forum/* 走 L1 会话鉴权，服务态
 * 调用没有用户令牌会 40101；/api/v1/forum/internal/* 才是 L2 且配额独立。
 * base_uri 只在本对端配置，全局 gateway.base_uri 保持为空，避免把考试平台
 * 的本地演示链路一并带出公网。
 */
$config['peers']['forum'] = [
    'enabled' => true,
    'name' => '论坛平台',
    'base_uri' => 'http://8.138.246.181',
    'app_code' => 'learning',
    'app_key' => 'jy-learning-svc',
    'app_secret' => '',
    'push_path' => '/api/v1/forum/internal/learning/progress',
    'events' => ['course.completed'],
    'extensions' => false,
    'extension_path' => '',
    'inbound' => true,
    'inbound_events' => ['forum.post.created', 'forum.reply.created'],
    'inbound_app_code' => 'forum',
    'secret' => '',
    'auth_mode' => 'auto',
    'token' => '',
    'query' => true,
    'access_token' => '',
    'headers' => [],
    'ack' => true,
    'pull' => true,
    'pull_limit' => 200,
    'replay' => true,
];


return $config;
