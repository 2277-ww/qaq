<?php
/**
 * 在真实 HTTP 环境下检查路由注册情况（临时脚本）
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');
header('Content-Type: text/plain; charset=utf-8');

require '/www/ctc/bootstrap/Kernel.php';
require '/www/ctc/bootstrap/HttpKernel.php';

$kernel = new \Bootstrap\HttpKernel();

$ref = new ReflectionClass($kernel);
$prop = $ref->getProperty('di');
$prop->setAccessible(true);
$di = $prop->getValue($kernel);

$router = $di->getShared('router');

$routes = $router->getRoutes();

echo '路由总数: ' . count($routes) . PHP_EOL;

$videoRoutes = [];
$hasVodSync = false;

foreach ($routes as $route) {
    $pattern = $route->getPattern();
    if (stripos($pattern, 'video') !== false) {
        $videoRoutes[] = $pattern . '  [' . $route->getName() . ']';
    }
    if ($route->getName() === 'admin.vod_sync.index') {
        $hasVodSync = true;
    }
}

echo '对照组 admin.vod_sync.index: ' . ($hasVodSync ? '已注册' : '未注册') . PHP_EOL;
echo '含 video 的路由 (' . count($videoRoutes) . '):' . PHP_EOL;
foreach ($videoRoutes as $item) {
    echo '  ' . $item . PHP_EOL;
}

echo PHP_EOL . '--- 匹配 /admin/video_upload/ ---' . PHP_EOL;
$router->handle('/admin/video_upload/');
echo 'module: ' . $router->getModuleName() . PHP_EOL;
echo 'controller: ' . $router->getControllerName() . PHP_EOL;
echo 'action: ' . $router->getActionName() . PHP_EOL;
echo 'namespace: ' . $router->getNamespaceName() . PHP_EOL;
$matched = $router->getMatchedRoute();
echo 'matched: ' . ($matched ? $matched->getPattern() : 'none') . PHP_EOL;
