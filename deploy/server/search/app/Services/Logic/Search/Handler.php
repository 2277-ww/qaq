<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Services\Logic\Search;

use App\Library\Paginator\Query as PagerQuery;
use App\Services\Logic\Service as LogicService;
use stdClass;

/**
 * 搜索基类
 *
 * 原实现依赖 XunSearch 服务端（xs-searchd，8383 端口）与预先构建的索引，
 * 但本项目部署环境既没有该服务，也没有任何索引构建入口，
 * 因此改为直接查询 MySQL，并在基类里统一处理分页与关键词。
 */
abstract class Handler extends LogicService
{

    /**
     * 每页条数上限
     */
    const MAX_KEYWORD_LENGTH = 50;

    /**
     * PHQL 绑定名计数器（同名占位符 + 数字后缀在 PHQL 里容易踩坑，用全局递增）
     */
    protected $bindSeq = 0;

    abstract function search();

    abstract function getHotQuery($limit, $type);

    abstract function getRelatedQuery($query, $limit);

    protected function handleKeywords($str)
    {
        $str = (string)$str;

        $str = kg_substr($str, 0, self::MAX_KEYWORD_LENGTH, '');

        return trim($str);
    }

    /**
     * 把关键词拆成多个检索词（空格分隔，全部命中才算匹配）
     *
     * @param string $keyword
     * @return array
     */
    protected function splitKeywords($keyword)
    {
        $keyword = trim((string)$keyword);

        if ($keyword === '') {
            return [];
        }

        // 中文连词当分隔符：「容器与部署」→「容器 部署」，
        // 否则整串 LIKE 匹配不到「Docker 容器化部署」这种标题
        $keyword = preg_replace('/(?<=[\x{4e00}-\x{9fa5}])[与和的及之或跟同](?=[\x{4e00}-\x{9fa5}])/u', ' ', $keyword);

        $terms = preg_split('/[\s,，、]+/u', $keyword, -1, PREG_SPLIT_NO_EMPTY);

        $result = [];

        foreach ((array)$terms as $term) {
            $term = trim($term);

            // 词首/词尾残留的连词（「与算法」→「算法」），去掉后至少保留 2 个字才生效
            $stripped = preg_replace('/^[与和的及之或跟同]+/u', '', $term);

            if (mb_strlen($stripped, 'UTF-8') >= 2) {
                $term = $stripped;
            }

            $stripped = preg_replace('/[与和的及之或跟同]+$/u', '', $term);

            if (mb_strlen($stripped, 'UTF-8') >= 2) {
                $term = $stripped;
            }

            if ($term === '' || mb_strlen($term, 'UTF-8') > 30) {
                continue;
            }

            $result[] = $term;
        }

        return array_slice(array_values(array_unique($result)), 0, 5);
    }

    /**
     * 取真正参与匹配的词
     *
     * 多词时把单字词（「与」「的」这类连词）降级为可选：
     * 例如分类名「Python 与算法」拆出 [Python, 与, 算法]，
     * 若强制三个词都命中，库里没有「与」就会 0 结果。
     * 只有一个词时保持原样（允许单字搜索）。
     *
     * @param array $terms
     * @return array
     */
    protected function searchableTerms(array $terms)
    {
        if (count($terms) <= 1) {
            return $terms;
        }

        $multi = [];

        foreach ($terms as $term) {
            if (mb_strlen($term, 'UTF-8') > 1) {
                $multi[] = $term;
            }
        }

        return empty($multi) ? $terms : array_values($multi);
    }

    /**
     * 生成 LIKE 参数，转义 MySQL 通配符
     */
    protected function likeParam($term)
    {
        $term = str_replace(['\\', '%', '_'], ['\\\\', '\%', '\_'], $term);

        return '%' . $term . '%';
    }

    /**
     * 单条记录在多个字段上的 OR 匹配条件
     *
     * @param string $alias 表别名
     * @param array $fields 参与匹配的字段
     * @param string $term 检索词
     * @param array $binds 绑定参数（引用传递）
     * @return string
     */
    protected function likeCondition($alias, array $fields, $term, array &$binds)
    {
        $parts = [];

        foreach ($fields as $field) {
            $key = 'kw' . $this->bindSeq++;
            $parts[] = sprintf('%s.%s LIKE :%s:', $alias, $field, $key);
            $binds[$key] = $this->likeParam($term);
        }

        return '(' . implode(' OR ', $parts) . ')';
    }

    /**
     * 单个检索词的完整条件：字段 LIKE 或 命中分类名
     *
     * 课程分类（前端开发 / 计算机视觉…）本身没有写进标题摘要，
     * 但用户会用分类名来搜，所以把分类表也纳入匹配。
     *
     * @param string $alias
     * @param array $fields
     * @param string $term
     * @param array $binds
     * @param bool $withCategory
     * @return string
     */
    protected function termCondition($alias, array $fields, $term, array &$binds, $withCategory = true)
    {
        $parts = [$this->likeCondition($alias, $fields, $term, $binds)];

        if ($withCategory) {
            $categoryIds = $this->getCategoryIdsByName($term);

            if (!empty($categoryIds)) {
                $key = 'cat' . $this->bindSeq++;
                $parts[] = sprintf('%s.category_id IN ({%s:array})', $alias, $key);
                $binds[$key] = $categoryIds;
            }
        }

        return '(' . implode(' OR ', $parts) . ')';
    }

    /**
     * 按名称模糊匹配分类 ID
     */
    protected function getCategoryIdsByName($term)
    {
        $rows = $this->modelsManager->executeQuery(
            'SELECT c.id FROM App\Models\Category c WHERE c.deleted = 0 AND c.name LIKE :kw:',
            ['kw' => $this->likeParam($term)]
        );

        $ids = [];

        foreach ($rows as $row) {
            $ids[] = (int)$row->id;
        }

        return $ids;
    }

    /**
     * 把记录集切成当前页
     */
    protected function sliceRows(array $rows, $page, $limit)
    {
        $offset = max(0, ($page - 1) * $limit);

        return array_slice($rows, $offset, $limit);
    }

    /**
     * 构造与前台模板（pager.total_items / total_pages / items / first…last）兼容的分页对象
     */
    protected function makePager(array $items, $totalItems, $page, $limit)
    {
        $pagerQuery = new PagerQuery();

        $baseUrl = $pagerQuery->getBaseUrl();

        if (empty($baseUrl)) {
            $baseUrl = '/search/';
        }

        $params = $pagerQuery->getParams();

        $totalPages = $limit > 0 ? (int)ceil($totalItems / $limit) : 0;

        $pager = new stdClass();

        $pager->total_items = (int)$totalItems;
        $pager->total_pages = $totalPages;
        $pager->items = $items;
        $pager->first = $this->pageUrl($baseUrl, $params, 1);
        $pager->previous = $this->pageUrl($baseUrl, $params, max(1, $page - 1));
        $pager->next = $this->pageUrl($baseUrl, $params, min(max($totalPages, 1), $page + 1));
        $pager->last = $this->pageUrl($baseUrl, $params, max($totalPages, 1));

        return $pager;
    }

    protected function pageUrl($baseUrl, array $params, $page)
    {
        $params['page'] = (int)$page;

        return $baseUrl . '?' . http_build_query($params);
    }

    /**
     * 关键词高亮，原文先做 HTML 转义
     */
    protected function highlight($text, array $terms)
    {
        $text = (string)$text;

        if ($text === '' || empty($terms)) {
            return htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
        }

        $text = htmlspecialchars($text, ENT_QUOTES, 'UTF-8');

        foreach ($terms as $term) {
            $term = htmlspecialchars($term, ENT_QUOTES, 'UTF-8');

            if ($term === '') {
                continue;
            }

            $text = str_ireplace($term, '<em>' . $term . '</em>', $text);
        }

        return $text;
    }

    /**
     * 补全封面地址
     */
    protected function coverUrl($cover)
    {
        $cover = (string)$cover;

        if ($cover === '') {
            return '';
        }

        if (strpos($cover, 'http') === 0) {
            return $cover;
        }

        return kg_cos_url() . $cover;
    }

    /**
     * 批量取分类名称 => ['id' => , 'name' => ]
     */
    protected function getCategoryMap(array $ids)
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));

        if (empty($ids)) {
            return [];
        }

        $rows = $this->modelsManager->executeQuery(
            'SELECT c.id, c.name FROM App\Models\Category c WHERE c.id IN ({ids:array})',
            ['ids' => $ids]
        );

        $map = [];

        foreach ($rows as $row) {
            $map[(int)$row->id] = ['id' => (int)$row->id, 'name' => (string)$row->name];
        }

        return $map;
    }

    /**
     * 批量取用户名称 => ['id' => , 'name' => ]
     */
    protected function getUserMap(array $ids)
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));

        if (empty($ids)) {
            return [];
        }

        $rows = $this->modelsManager->executeQuery(
            'SELECT u.id, u.name FROM App\Models\User u WHERE u.id IN ({ids:array})',
            ['ids' => $ids]
        );

        $map = [];

        foreach ($rows as $row) {
            $map[(int)$row->id] = ['id' => (int)$row->id, 'name' => (string)$row->name];
        }

        return $map;
    }

    protected function decodeJson($value)
    {
        if (is_array($value)) {
            return $value;
        }

        $decoded = json_decode((string)$value, true);

        return is_array($decoded) ? $decoded : [];
    }

}
