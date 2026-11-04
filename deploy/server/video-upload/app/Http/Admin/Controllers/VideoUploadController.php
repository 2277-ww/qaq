<?php
/**
 * 演示视频上传控制器
 *
 * 独立入口，不经过原项目的 COS / 点播同步链路。
 * 前端按 8MB 分片推送，服务端合并后归档到 /www/media/vod。
 */

namespace App\Http\Admin\Controllers;

use App\Http\Admin\Services\VideoUpload as VideoUploadService;

/**
 * @RoutePrefix("/admin/video_upload")
 */
class VideoUploadController extends Controller
{

    /**
     * 上传页
     *
     * @Get("/", name="admin.video_upload.index")
     */
    public function indexAction()
    {
        $service = new VideoUploadService();

        $this->view->pick('video_upload/index');

        $this->view->setVar('courses', $service->getCourses());
        $this->view->setVar('stat', $service->getStat());
    }

    /**
     * 媒体库
     *
     * @Get("/list", name="admin.video_upload.list")
     */
    public function listAction()
    {
        $service = new VideoUploadService();

        $service->cleanExpired();

        $this->view->pick('video_upload/list');

        $this->view->setVar('files', $service->listFiles());
        $this->view->setVar('stat', $service->getStat());
    }

    /**
     * 初始化上传会话
     *
     * @Post("/init", name="admin.video_upload.init")
     */
    public function initAction()
    {
        $service = new VideoUploadService();

        $courseId = $this->request->getPost('course_id', 'int', 0);
        $filename = $this->request->getPost('filename', 'string', '');
        $size = $this->request->getPost('size', 'int', 0);

        $result = $service->init($courseId, $filename, $size);

        return $this->respond($result);
    }

    /**
     * 接收单个分片
     *
     * @Post("/chunk", name="admin.video_upload.chunk")
     */
    public function chunkAction()
    {
        $service = new VideoUploadService();

        $uploadId = $this->request->getPost('upload_id', 'string', '');
        $index = $this->request->getPost('index', 'int', -1);

        $files = $this->request->getUploadedFiles();

        $chunk = null;

        foreach ($files as $file) {
            if ($file->getName() === 'chunk' || $chunk === null) {
                $chunk = $file;
            }
        }

        if (!$chunk) {
            return $this->jsonError(['msg' => '未收到分片数据']);
        }

        if (!$chunk->isUploadedFile()) {
            return $this->jsonError(['msg' => '分片上传失败，可能超过 post_max_size 限制']);
        }

        $result = $service->saveChunk($uploadId, $index, $chunk->getTempName());

        return $this->respond($result);
    }

    /**
     * 合并分片并归档
     *
     * @Post("/finish", name="admin.video_upload.finish")
     */
    public function finishAction()
    {
        $service = new VideoUploadService();

        $uploadId = $this->request->getPost('upload_id', 'string', '');

        $result = $service->finish($uploadId);

        return $this->respond($result);
    }

    /**
     * 绑定到课程章节
     *
     * @Post("/attach", name="admin.video_upload.attach")
     */
    public function attachAction()
    {
        $service = new VideoUploadService();

        $courseId = $this->request->getPost('course_id', 'int', 0);
        $chapterId = $this->request->getPost('chapter_id', 'int', 0);
        $url = $this->request->getPost('url', 'string', '');

        $result = $service->attach($courseId, $chapterId, $url);

        return $this->respond($result);
    }

    /**
     * 章节列表（供联动下拉使用）
     *
     * @Get("/chapters", name="admin.video_upload.chapters")
     */
    public function chaptersAction()
    {
        $service = new VideoUploadService();

        $courseId = $this->request->getQuery('course_id', 'int', 0);

        return $this->jsonSuccess(['items' => $service->getChapters($courseId)]);
    }

    /**
     * 删除媒体文件
     *
     * @Post("/delete", name="admin.video_upload.delete")
     */
    public function deleteAction()
    {
        $service = new VideoUploadService();

        $url = $this->request->getPost('url', 'string', '');

        $result = $service->remove($url);

        return $this->respond($result);
    }

    /**
     * 统一输出
     */
    protected function respond($result)
    {
        if (isset($result['code']) && $result['code'] == 0) {
            $content = $result['data'] ?? [];
            $content['msg'] = $result['msg'] ?? 'ok';
            return $this->jsonSuccess($content);
        }

        return $this->jsonError(['msg' => $result['msg'] ?? '操作失败']);
    }

}
