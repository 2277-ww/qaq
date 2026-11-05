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
$config['key'] = getenv('CTC_APP_KEY') ?: 'PUT-YOUR-APP-KEY-HERE';

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
$config['static_version'] = '202611041350';

/**
 * 数据库主机名
 */
$config['db']['host'] = '127.0.0.1';

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
$config['db']['password'] = getenv('CTC_DB_PASSWORD') ?: 'PUT-YOUR-DB-PASSWORD-HERE';

/**
 * 数据库编码
 */
$config['db']['charset'] = 'utf8mb4';

/**
 * redis主机名
 */
$config['redis']['host'] = '127.0.0.1';

/**
 * redis端口号
 */
$config['redis']['port'] = 6379;

/**
 * redis库编号
 */
$config['redis']['index'] = 3;

/**
 * redis密码
 */
$config['redis']['auth'] = '';

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
$config['websocket']['connect_address'] = '127.0.0.1:8282';

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
 * 成长档案同步
 *
 * endpoint: 全局个人成长档案的接收地址。留空表示本地直连模式，
 *           事件入箱后直接标记为已投递（用于本地复现环境）。
 * note_content_sync: 笔记正文是否随事件上报。关闭后只上报条数与摘要。
 */
$config['growth']['endpoint'] = '';

$config['growth']['note_content_sync'] = true;

$config['growth']['timeout'] = 5;

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
 * 内置身份（无登录模式）
 *
 * 本复现环境不提供注册与登录入口，所有前台/后台请求统一以内置账号的身份执行。
 * user_id 必须是一个真实存在的 kg_user 记录，后台还需其 admin_role 具备管理权限。
 * 如需恢复账号体系，将 enabled 置为 false 即可。
 */
$config['identity']['enabled'] = true;

$config['identity']['user_id'] = 10000;

/**
 * 品牌标识（唯一配置入口）
 *
 * 全站的应用名称、Logo、标语、页脚署名均从此处读取，视图与控制器不得硬编码。
 * 如需更换品牌，只改这一处（以及 public/static 下的图片资源）即可。
 *
 * name       应用名称，用于浏览器标题、页脚、后台侧栏等文字标识
 * alias      英文简称，用于版本号署名
 * slogan     一句话标语
 * logo       浅色版 Logo（深色背景使用），相对 public/static 的路径
 * logo_dark  深色版 Logo（浅色背景使用）
 * favicon    站点图标
 * title_separator 页面标题分隔符
 * powered_by 页脚署名文字，留空则不显示
 */
$config['brand']['name'] = '自学平台';

$config['brand']['alias'] = 'SelfLearn';

$config['brand']['slogan'] = '面向警务人才培养的自主学习平台';

$config['brand']['logo'] = 'brand-logo.png';

$config['brand']['logo_dark'] = 'brand-logo-dark.png';

$config['brand']['favicon'] = 'favicon.ico';

$config['brand']['title_separator'] = ' - ';

$config['brand']['powered_by'] = '';

return $config;
