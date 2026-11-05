<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

use Phalcon\Mvc\Router\Annotations as Router;

$router = new Router(false);

$router->removeExtraSlashes(true);

$router->setDefaultNamespace('App\Http\Home\Controllers');

$router->notFound([
    'module' => 'home',
    'controller' => 'error',
    'action' => 'show404',
]);

/**
 * 统一网关 · 服务间调用别名
 *
 * 网关把「服务态（L2 机器调用）」和「用户态（L1 会话）」按路径前缀分开：
 *   /api/v1/learning/internal/*   L2 签名 + 200 QPS/AppKey
 *   /api/v1/learning/*            L1 会话，无令牌直接 40101
 *
 * 对端平台（考试、论坛）没有用户令牌，只能走 L2 那条。因此给 peers 这一整组
 * 动作注册一份 /internal 前缀的等价入口，让它们落进网关已有的 L2 路由——
 * 网关侧不需要新增或修改任何路由。
 *
 * 注解路由本身无法为一个动作声明多个 URI，所以在这里显式登记，并且必须放在
 * addModuleResource 之前：Phalcon 按注册顺序匹配，先登记的先命中。
 *
 * 原路径 /api/v1/learning/peers/* 保留，用于内网直连与本地联调；
 * 对外接入一律用 /internal 前缀，避免被 L1 拦掉。
 */
$peerAliases = [
    ''                                                                         => ['peers', ['GET']],
    '/{source}/handshake'                                                      => ['peerHandshake', ['GET']],
    '/{source}/students/{userId:[A-Za-z0-9_\-]+}/progress'                     => ['peerStudentProgress', ['GET']],
    '/{source}/students/{userId:[A-Za-z0-9_\-]+}/completion/{courseId:[0-9]+}'  => ['peerStudentCompletion', ['GET']],
    '/{source}/events'                                                         => ['peerEvent', ['POST']],
    '/{source}/events/{eventId}'                                               => ['peerEventStatus', ['GET']],
    '/{source}/receipts'                                                       => ['peerReceipt', ['POST']],
    '/{source}/pull'                                                           => ['peerPull', ['GET']],
    '/{source}/replay'                                                         => ['peerReplay', ['POST']],
];

foreach ($peerAliases as $suffix => $spec) {

    list($action, $methods) = $spec;

    $route = $router->add('/api/v1/learning/internal/peers' . $suffix, [
        'module' => 'api',
        'namespace' => 'App\Http\Api\Controllers',
        'controller' => 'learning',
        'action' => $action,
    ]);

    $route->setMethods($methods);

    $route->setName('api.learning.internal_' . $action);
}

$modules = ['api', 'home', 'admin'];

foreach ($modules as $module) {
    $moduleName = ucfirst($module);
    $files = scandir(app_path('Http/' . $moduleName . '/Controllers'));
    foreach ($files as $file) {
        if (preg_match('/^\w+Controller\.php$/', $file)) {
            $className = str_replace('Controller.php', '', $file);
            $router->addModuleResource($module, 'App\Http\\' . $moduleName . '\Controllers\\' . $className);
        }
    }
}

return $router;