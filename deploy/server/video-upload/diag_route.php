<?php
/**
 * 路由与类加载诊断（临时脚本，用完删除）
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

$appDir = '/www/ctc/app';

echo "=== 1. scandir 是否能扫到 ===\n";
$dir = $appDir . '/Http/Admin/Controllers';
$files = scandir($dir);
$hit = array_values(array_filter($files, function ($f) {
    return stripos($f, 'VideoUpload') !== false;
}));
echo 'controllers 总数: ' . count($files) . PHP_EOL;
echo '匹配 VideoUpload: ' . json_encode($hit) . PHP_EOL;
echo '正则校验: ' . (preg_match('/^\w+Controller\.php$/', 'VideoUploadController.php') ? 'pass' : 'fail') . PHP_EOL;

echo "\n=== 2. autoload 是否能加载类 ===\n";
$loader = new \Phalcon\Loader();
$loader->registerNamespaces([
    'App' => $appDir,
    'Bootstrap' => '/www/ctc/bootstrap',
]);
$loader->registerFiles(['/www/ctc/vendor/autoload.php']);
$loader->register();

$classes = [
    'App\Http\Admin\Controllers\VideoUploadController',
    'App\Http\Admin\Controllers\VodSyncController',
    'App\Http\Admin\Services\VideoUpload',
];

foreach ($classes as $cls) {
    echo str_pad($cls, 55) . (class_exists($cls) ? 'OK' : 'FAIL') . PHP_EOL;
}

echo "\n=== 3. 注解是否可解析 ===\n";
$reader = new \Phalcon\Annotations\Adapter\Memory();

foreach (['App\Http\Admin\Controllers\VideoUploadController', 'App\Http\Admin\Controllers\VodSyncController'] as $cls) {
    if (!class_exists($cls)) {
        echo str_pad($cls, 55) . 'class missing' . PHP_EOL;
        continue;
    }
    try {
        $reflection = new ReflectionClass($cls);
        $classAnn = $reader->getClassAnnotations($reflection);
        $prefix = $classAnn ? $classAnn->get('RoutePrefix') : null;
        echo str_pad($cls, 55) . ($prefix ? 'prefix=' . $prefix->getArguments()[0] : 'no prefix') . PHP_EOL;

        $methods = $reflection->getMethods(ReflectionMethod::IS_PUBLIC);
        $routes = [];
        foreach ($methods as $m) {
            $ann = $reader->getMethodAnnotations($m);
            if (!$ann) {
                continue;
            }
            foreach ($ann->getAnnotations() as $a) {
                $name = $a->getName();
                if (in_array($name, ['Get', 'Post', 'Route'])) {
                    $args = $a->getArguments();
                    $routes[] = $name . ' ' . ($args[0] ?? '') . ' -> ' . $m->getName();
                }
            }
        }
        echo '  路由数: ' . count($routes) . PHP_EOL;
        foreach ($routes as $r) {
            echo '    ' . $r . PHP_EOL;
        }
    } catch (\Throwable $e) {
        echo 'ERROR: ' . get_class($e) . ' ' . $e->getMessage() . PHP_EOL;
    }
}
