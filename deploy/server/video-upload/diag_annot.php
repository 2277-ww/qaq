<?php
/**
 * 注解解析检查（Phalcon 3.4 API）
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');
header('Content-Type: text/plain; charset=utf-8');

$loader = new \Phalcon\Loader();
$loader->registerNamespaces([
    'App' => '/www/ctc/app',
    'Bootstrap' => '/www/ctc/bootstrap',
]);
$loader->registerFiles(['/www/ctc/vendor/autoload.php']);
$loader->register();

$targets = [
    'App\Http\Admin\Controllers\VodSyncController',
    'App\Http\Admin\Controllers\VideoUploadController',
];

$reader = new \Phalcon\Annotations\Adapter\Memory();

foreach ($targets as $cls) {
    echo '===== ' . $cls . ' =====' . PHP_EOL;

    if (!class_exists($cls)) {
        echo 'class not found' . PHP_EOL;
        continue;
    }

    try {
        $reflection = $reader->get($cls);

        $classAnn = $reflection->getClassAnnotations();

        if ($classAnn) {
            foreach ($classAnn->getAnnotations() as $a) {
                echo '  class @' . $a->getName() . ' ' . json_encode($a->getArguments(), JSON_UNESCAPED_UNICODE) . PHP_EOL;
            }
        } else {
            echo '  no class annotations' . PHP_EOL;
        }

        $methodAnn = $reflection->getMethodsAnnotations();

        if ($methodAnn) {
            foreach ($methodAnn as $method => $ann) {
                foreach ($ann->getAnnotations() as $a) {
                    echo '  method ' . $method . ' @' . $a->getName() . ' ' . json_encode($a->getArguments(), JSON_UNESCAPED_UNICODE) . PHP_EOL;
                }
            }
        }
    } catch (\Throwable $e) {
        echo '  ERROR: ' . get_class($e) . ': ' . $e->getMessage() . PHP_EOL;
    }

    echo PHP_EOL;
}
