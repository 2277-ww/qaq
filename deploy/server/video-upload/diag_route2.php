<?php
/**
 * 手动注册单个控制器并测试匹配（临时脚本）
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

\Phalcon\Di::setDefault($di);

echo '--- 注解服务: ' . (get_class($di->getShared('annotations'))) . PHP_EOL;

$router = new \Phalcon\Mvc\Router\Annotations(false);
$router->removeExtraSlashes(true);
$router->setDefaultNamespace('App\Http\Home\Controllers');

$result = $router->addModuleResource('admin', 'App\Http\Admin\Controllers\VideoUploadController');
echo 'addModuleResource 返回: ' . var_export($result, true) . PHP_EOL;

$patterns = [];
foreach ($router->getRoutes() as $r) {
    $patterns[] = $r->getPattern() . ' [' . $r->getName() . ']';
}
echo '注册路由数: ' . count($patterns) . PHP_EOL;
foreach ($patterns as $p) {
    echo '  ' . $p . PHP_EOL;
}

echo PHP_EOL . '--- handle /admin/video_upload ---' . PHP_EOL;
$router->handle('/admin/video_upload');
echo 'module=' . $router->getModuleName() . ' controller=' . $router->getControllerName()
    . ' action=' . $router->getActionName() . PHP_EOL;

echo PHP_EOL . '--- handle /admin/video_upload/list ---' . PHP_EOL;
$router->handle('/admin/video_upload/list');
echo 'module=' . $router->getModuleName() . ' controller=' . $router->getControllerName()
    . ' action=' . $router->getActionName() . PHP_EOL;

echo PHP_EOL . '--- 对照: 注册 VodSyncController ---' . PHP_EOL;
$router2 = new \Phalcon\Mvc\Router\Annotations(false);
$router2->removeExtraSlashes(true);
$router2->addModuleResource('admin', 'App\Http\Admin\Controllers\VodSyncController');
$router2->handle('/admin/vod_sync');
echo 'module=' . $router2->getModuleName() . ' controller=' . $router2->getControllerName()
    . ' action=' . $router2->getActionName() . PHP_EOL;
