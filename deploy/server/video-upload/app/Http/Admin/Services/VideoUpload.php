<?php
/**
 * 演示视频本地上传服务
 *
 * 独立于原项目的 COS / 云点播链路：文件直接落在本机磁盘，
 * 由 nginx 以 /media/vod/ 暴露为直链，播放地址写回 kg_chapter_vod.file_remote。
 *
 * 存储布局：
 *   /www/media/vod/{course_id}/{Ym}/{upload_id}.{ext}   正式文件
 *   /www/media/tmp/{upload_id}/{index}.part             分片暂存（合并后删除）
 */

namespace App\Http\Admin\Services;

use App\Models\Chapter as ChapterModel;
use App\Models\ChapterVod as ChapterVodModel;
use App\Models\Course as CourseModel;
use Phalcon\Di\Injectable;

class VideoUpload extends Injectable
{

    /**
     * 单文件上限 500MB
     */
    const MAX_SIZE = 524288000;

    /**
     * 分片大小 8MB
     */
    const CHUNK_SIZE = 8388608;

    /**
     * 媒体根目录（位于 web 根之外）
     */
    const MEDIA_ROOT = '/www/media/vod';

    /**
     * 分片暂存目录
     */
    const TMP_ROOT = '/www/media/tmp';

    /**
     * 允许的容器格式
     */
    const ALLOWED_EXT = ['mp4', 'webm', 'm4v'];

    /**
     * 上传地址前缀
     */
    const URL_PREFIX = '/media/vod/';

    /**
     * 初始化上传会话
     *
     * @param int $courseId 课程编号
     * @param string $filename 原始文件名
     * @param int $size 字节数
     * @return array
     */
    public function init($courseId, $filename, $size)
    {
        $courseId = (int)$courseId;
        $size = (int)$size;
        $filename = trim((string)$filename);

        if ($courseId <= 0) {
            return $this->fail('请先选择所属课程');
        }

        if ($size <= 0) {
            return $this->fail('文件内容为空');
        }

        if ($size > self::MAX_SIZE) {
            return $this->fail(sprintf('文件 %s 超过 %s 上限', $this->readable($size), $this->readable(self::MAX_SIZE)));
        }

        $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

        if (!in_array($ext, self::ALLOWED_EXT)) {
            return $this->fail('仅支持 mp4 / webm / m4v 格式');
        }

        $course = CourseModel::findFirst([
            'id = ?0 AND deleted = 0',
            'bind' => [$courseId],
        ]);

        if (!$course) {
            return $this->fail('课程不存在或已删除');
        }

        if (!$this->ensureDir(self::TMP_ROOT)) {
            return $this->fail('临时目录不可写，请检查 /www/media/tmp 权限');
        }

        $uploadId = bin2hex(random_bytes(16));

        $dir = self::TMP_ROOT . '/' . $uploadId;

        if (!@mkdir($dir, 0775, true)) {
            return $this->fail('无法创建上传会话目录');
        }

        $totalChunks = (int)ceil($size / self::CHUNK_SIZE);

        $meta = [
            'upload_id' => $uploadId,
            'course_id' => $courseId,
            'filename' => $filename,
            'size' => $size,
            'ext' => $ext,
            'chunks' => $totalChunks,
            'created' => time(),
        ];

        file_put_contents($dir . '/meta.json', json_encode($meta, JSON_UNESCAPED_UNICODE));

        return [
            'code' => 0,
            'msg' => 'ok',
            'data' => [
                'upload_id' => $uploadId,
                'chunk_size' => self::CHUNK_SIZE,
                'total_chunks' => $totalChunks,
            ],
        ];
    }

    /**
     * 保存单个分片
     *
     * @param string $uploadId 会话标识
     * @param int $index 分片序号，从 0 开始
     * @param string $tmpFile PHP 临时文件路径
     * @return array
     */
    public function saveChunk($uploadId, $index, $tmpFile)
    {
        if (!$this->isValidId($uploadId)) {
            return $this->fail('上传标识非法');
        }

        $dir = self::TMP_ROOT . '/' . $uploadId;

        $meta = $this->readMeta($dir);

        if (!$meta) {
            return $this->fail('上传会话不存在或已过期');
        }

        $index = (int)$index;

        if ($index < 0 || $index >= (int)$meta['chunks']) {
            return $this->fail('分片序号越界');
        }

        $target = $dir . '/' . $index . '.part';

        $ok = is_uploaded_file($tmpFile)
            ? @move_uploaded_file($tmpFile, $target)
            : @copy($tmpFile, $target);

        if (!$ok) {
            return $this->fail('分片写入失败，请检查磁盘空间');
        }

        return [
            'code' => 0,
            'msg' => 'ok',
            'data' => ['index' => $index],
        ];
    }

    /**
     * 合并分片、校验并归档
     *
     * @param string $uploadId 会话标识
     * @return array
     */
    public function finish($uploadId)
    {
        if (!$this->isValidId($uploadId)) {
            return $this->fail('上传标识非法');
        }

        $dir = self::TMP_ROOT . '/' . $uploadId;

        $meta = $this->readMeta($dir);

        if (!$meta) {
            return $this->fail('上传会话不存在或已过期');
        }

        $total = (int)$meta['chunks'];

        $missing = [];

        for ($i = 0; $i < $total; $i++) {
            $part = $dir . '/' . $i . '.part';
            if (!is_file($part) || filesize($part) === 0) {
                $missing[] = $i;
            }
        }

        if (!empty($missing)) {
            return $this->fail(sprintf('分片不完整，缺少 %d 个（首个序号 %d），请重传', count($missing), $missing[0]));
        }

        $merged = $dir . '/merged.tmp';

        $out = @fopen($merged, 'wb');

        if (!$out) {
            return $this->fail('无法创建合并文件，请检查磁盘空间');
        }

        for ($i = 0; $i < $total; $i++) {
            $in = @fopen($dir . '/' . $i . '.part', 'rb');
            if (!$in) {
                fclose($out);
                @unlink($merged);
                return $this->fail('分片读取失败');
            }
            stream_copy_to_stream($in, $out);
            fclose($in);
        }

        fclose($out);

        $realSize = filesize($merged);

        if ($realSize !== (int)$meta['size']) {
            @unlink($merged);
            return $this->fail(sprintf('合并后大小不符：实际 %d 字节，应为 %d 字节', $realSize, $meta['size']));
        }

        $format = $this->sniff($merged);

        if ($format === null) {
            @unlink($merged);
            return $this->fail('文件内容不是有效的 MP4 / WebM 视频（已校验容器魔数）');
        }

        $courseId = (int)$meta['course_id'];

        $ym = date('Ym');

        $subDir = self::MEDIA_ROOT . '/' . $courseId . '/' . $ym;

        if (!$this->ensureDir($subDir)) {
            @unlink($merged);
            return $this->fail('媒体目录不可写，请检查 /www/media/vod 权限');
        }

        $ext = $format === 'webm' ? 'webm' : $meta['ext'];

        $basename = $uploadId . '.' . $ext;

        $dest = $subDir . '/' . $basename;

        if (!@rename($merged, $dest)) {
            @unlink($merged);
            return $this->fail('文件归档失败');
        }

        @chmod($dest, 0664);

        $this->cleanTmp($dir);

        $url = self::URL_PREFIX . $courseId . '/' . $ym . '/' . $basename;

        return [
            'code' => 0,
            'msg' => '上传完成',
            'data' => [
                'url' => $url,
                'size' => $realSize,
                'filename' => $meta['filename'],
                'course_id' => $courseId,
                'format' => $format,
            ],
        ];
    }

    /**
     * 把已上传的文件绑定到课程章节
     *
     * @param int $courseId 课程编号
     * @param int $chapterId 章节编号
     * @param string $url 播放地址
     * @return array
     */
    public function attach($courseId, $chapterId, $url)
    {
        $courseId = (int)$courseId;
        $chapterId = (int)$chapterId;

        if ($courseId <= 0 || $chapterId <= 0) {
            return $this->fail('请选择课程与章节');
        }

        if (!$this->isValidUrl($url)) {
            return $this->fail('播放地址非法');
        }

        if (!$this->fileExists($url)) {
            return $this->fail('文件不存在，可能已被删除');
        }

        $chapter = ChapterModel::findFirst([
            'id = ?0 AND course_id = ?1 AND deleted = 0',
            'bind' => [$chapterId, $courseId],
        ]);

        if (!$chapter) {
            return $this->fail('所选章节不属于该课程');
        }

        $remote = [
            'hd' => ['url' => $url],
            'sd' => ['url' => $url],
            'fd' => ['url' => $url],
        ];

        $row = ChapterVodModel::findFirst([
            'chapter_id = ?0',
            'bind' => [$chapterId],
        ]);

        if (!$row) {
            $row = new ChapterVodModel();
        }

        $row->course_id = $courseId;
        $row->chapter_id = $chapterId;
        $row->file_id = '';
        $row->file_transcode = [];
        $row->file_remote = $remote;

        if (!$row->save()) {
            return $this->fail('写入播放地址失败');
        }

        return [
            'code' => 0,
            'msg' => '已绑定到章节',
            'data' => [
                'chapter_id' => $chapterId,
                'chapter_title' => $chapter->title,
                'url' => $url,
            ],
        ];
    }

    /**
     * 列出媒体库文件
     *
     * @return array
     */
    public function listFiles()
    {
        $root = self::MEDIA_ROOT;

        $items = [];

        if (!is_dir($root)) {
            return $items;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($root, \FilesystemIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            if (!$file->isFile()) {
                continue;
            }

            $ext = strtolower($file->getExtension());

            if (!in_array($ext, ['mp4', 'webm', 'm4v'])) {
                continue;
            }

            $path = $file->getPathname();

            $rel = substr($path, strlen($root));

            $items[] = [
                'url' => self::URL_PREFIX . ltrim($rel, '/'),
                'size' => $file->getSize(),
                'size_text' => $this->readable($file->getSize()),
                'mtime' => $file->getMTime(),
                'mtime_text' => date('Y-m-d H:i', $file->getMTime()),
            ];
        }

        usort($items, function ($a, $b) {
            return $b['mtime'] <=> $a['mtime'];
        });

        return $items;
    }

    /**
     * 删除媒体库文件
     *
     * @param string $url 播放地址
     * @return array
     */
    public function remove($url)
    {
        if (!$this->isValidUrl($url)) {
            return $this->fail('播放地址非法');
        }

        $path = $this->urlToPath($url);

        if (!is_file($path)) {
            return $this->fail('文件不存在');
        }

        if (!@unlink($path)) {
            return $this->fail('删除失败，请检查文件权限');
        }

        return ['code' => 0, 'msg' => '已删除', 'data' => ['url' => $url]];
    }

    /**
     * 清理超过 24 小时未完成的临时会话
     *
     * @return int 清理数量
     */
    public function cleanExpired()
    {
        if (!is_dir(self::TMP_ROOT)) {
            return 0;
        }

        $count = 0;

        $deadline = time() - 86400;

        foreach (glob(self::TMP_ROOT . '/*', GLOB_ONLYDIR) as $dir) {
            $meta = $this->readMeta($dir);
            if ($meta && (int)$meta['created'] > $deadline) {
                continue;
            }
            $this->cleanTmp($dir);
            $count++;
        }

        return $count;
    }

    /**
     * 课程下拉数据
     *
     * @return array
     */
    public function getCourses()
    {
        $courses = CourseModel::find([
            'conditions' => 'deleted = 0',
            'columns' => 'id, title',
            'order' => 'id ASC',
        ]);

        $items = [];

        foreach ($courses as $course) {
            $items[] = ['id' => (int)$course->id, 'title' => $course->title];
        }

        return $items;
    }

    /**
     * 章节下拉数据
     *
     * @param int $courseId 课程编号
     * @return array
     */
    public function getChapters($courseId)
    {
        $courseId = (int)$courseId;

        if ($courseId <= 0) {
            return [];
        }

        $chapters = ChapterModel::find([
            'conditions' => 'course_id = ?0 AND deleted = 0',
            'bind' => [$courseId],
            'columns' => 'id, title, parent_id',
            'order' => 'priority ASC, id ASC',
        ]);

        $items = [];

        foreach ($chapters as $chapter) {
            $items[] = [
                'id' => (int)$chapter->id,
                'title' => $chapter->title,
                'parent_id' => (int)$chapter->parent_id,
            ];
        }

        return $items;
    }

    /**
     * 媒体目录与磁盘现状
     *
     * @return array
     */
    public function getStat()
    {
        $free = @disk_free_space(self::MEDIA_ROOT);

        $total = 0;

        if (is_dir(self::MEDIA_ROOT)) {
            $iterator = new \RecursiveIteratorIterator(
                new \RecursiveDirectoryIterator(self::MEDIA_ROOT, \FilesystemIterator::SKIP_DOTS)
            );
            foreach ($iterator as $file) {
                if ($file->isFile()) {
                    $total += $file->getSize();
                }
            }
        }

        return [
            'media_root' => self::MEDIA_ROOT,
            'used' => $total,
            'used_text' => $this->readable($total),
            'free_text' => $free === false ? '未知' : $this->readable($free),
            'max_size' => self::MAX_SIZE,
            'max_size_text' => $this->readable(self::MAX_SIZE),
            'allowed_ext' => implode(' / ', self::ALLOWED_EXT),
            'chunk_size' => self::CHUNK_SIZE,
            'chunk_size_text' => $this->readable(self::CHUNK_SIZE),
        ];
    }

    /**
     * 校验上传标识
     */
    protected function isValidId($uploadId)
    {
        return is_string($uploadId) && preg_match('/^[a-f0-9]{32}$/', $uploadId) === 1;
    }

    /**
     * 校验播放地址是否落在媒体目录内
     */
    protected function isValidUrl($url)
    {
        if (!is_string($url) || strpos($url, self::URL_PREFIX) !== 0) {
            return false;
        }

        if (strpos($url, '..') !== false) {
            return false;
        }

        return preg_match('#^/media/vod/[\w\-]+/[\w\-/]+\.[A-Za-z0-9]+$#', $url) === 1;
    }

    protected function urlToPath($url)
    {
        return self::MEDIA_ROOT . '/' . ltrim(substr($url, strlen(self::URL_PREFIX)), '/');
    }

    protected function fileExists($url)
    {
        return is_file($this->urlToPath($url));
    }

    /**
     * 读取会话元数据
     */
    protected function readMeta($dir)
    {
        $file = $dir . '/meta.json';

        if (!is_file($file)) {
            return null;
        }

        $meta = json_decode(file_get_contents($file), true);

        if (!is_array($meta) || empty($meta['chunks'])) {
            return null;
        }

        return $meta;
    }

    /**
     * 清理临时会话目录
     */
    protected function cleanTmp($dir)
    {
        if (!is_dir($dir)) {
            return;
        }

        foreach (glob($dir . '/*') as $file) {
            if (is_file($file)) {
                @unlink($file);
            }
        }

        @rmdir($dir);
    }

    protected function ensureDir($dir)
    {
        if (is_dir($dir)) {
            return is_writable($dir);
        }

        return @mkdir($dir, 0775, true);
    }

    /**
     * 通过容器魔数识别真实格式，不信任扩展名与 Content-Type
     *
     * @param string $path
     * @return string|null mp4 / webm / null
     */
    protected function sniff($path)
    {
        $handle = @fopen($path, 'rb');

        if (!$handle) {
            return null;
        }

        $head = fread($handle, 16);

        fclose($handle);

        if (strlen($head) >= 12 && substr($head, 4, 4) === 'ftyp') {
            return 'mp4';
        }

        if (strlen($head) >= 4 && substr($head, 0, 4) === "\x1A\x45\xDF\xA3") {
            return 'webm';
        }

        return null;
    }

    protected function readable($bytes)
    {
        $bytes = (int)$bytes;

        if ($bytes >= 1073741824) {
            return round($bytes / 1073741824, 2) . ' GB';
        }

        if ($bytes >= 1048576) {
            return round($bytes / 1048576, 1) . ' MB';
        }

        if ($bytes >= 1024) {
            return round($bytes / 1024, 1) . ' KB';
        }

        return $bytes . ' B';
    }

    protected function fail($msg)
    {
        return ['code' => 1, 'msg' => $msg];
    }

}
