<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Services\Logic\Search;

use App\Library\Paginator\Query as PagerQuery;

class Course extends Handler
{

    public function search()
    {
        $pagerQuery = new PagerQuery();

        $params = $pagerQuery->getParams();
        $page = $pagerQuery->getPage();
        $limit = $pagerQuery->getLimit();

        $keyword = $this->handleKeywords($params['query'] ?? '');

        $terms = $this->searchableTerms($this->splitKeywords($keyword));

        $phql = 'SELECT c.id, c.title, c.cover, c.summary, c.keywords, c.tags,'
            . ' c.category_id, c.teacher_id, c.model, c.level, c.rating,'
            . ' c.market_price, c.vip_price, c.user_count, c.lesson_count,'
            . ' c.review_count, c.favorite_count'
            . ' FROM App\Models\Course c'
            . ' WHERE c.deleted = 0 AND c.published = 1';

        $binds = [];

        $fields = ['title', 'summary', 'keywords', 'tags'];

        foreach ($terms as $index => $term) {
            $phql .= ' AND ' . $this->termCondition('c', $fields, $term, $binds);
        }

        $phql .= ' ORDER BY c.id DESC';

        $rows = $this->modelsManager->executeQuery($phql, $binds)->toArray();

        $totalItems = count($rows);

        $rows = $this->sliceRows($rows, $page, $limit);

        $categoryMap = $this->getCategoryMap(array_column($rows, 'category_id'));
        $teacherMap = $this->getUserMap(array_column($rows, 'teacher_id'));

        $items = [];

        foreach ($rows as $row) {

            $categoryId = (int)$row['category_id'];
            $teacherId = (int)$row['teacher_id'];

            $category = $categoryMap[$categoryId] ?? ['id' => $categoryId, 'name' => '未分类'];
            $teacher = $teacherMap[$teacherId] ?? ['id' => $teacherId, 'name' => '未知讲师'];

            $items[] = [
                'id' => (int)$row['id'],
                'title' => $this->highlight($row['title'], $terms),
                'cover' => $this->coverUrl($row['cover']),
                'summary' => $this->highlight($row['summary'], $terms),
                'model' => (int)$row['model'],
                'level' => (int)$row['level'],
                'rating' => round((float)$row['rating'], 1),
                'market_price' => (float)$row['market_price'],
                'vip_price' => (float)$row['vip_price'],
                'user_count' => (int)$row['user_count'],
                'lesson_count' => (int)$row['lesson_count'],
                'review_count' => (int)$row['review_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'category' => $category,
                'teacher' => $teacher,
                'tags' => $this->decodeJson($row['tags']),
            ];
        }

        return $this->makePager($items, $totalItems, $page, $limit);
    }

    public function getHotQuery($limit = 10, $type = 'total')
    {
        $limit = max(1, min(20, (int)$limit));

        $rows = $this->modelsManager->executeQuery(
            'SELECT c.name FROM App\Models\Category c'
            . ' WHERE c.parent_id = 0 AND c.published = 1 AND c.deleted = 0'
            . ' ORDER BY c.priority DESC, c.id ASC LIMIT ' . $limit
        );

        $result = [];

        foreach ($rows as $row) {
            $result[] = (string)$row->name;
        }

        return $result;
    }

    public function getRelatedQuery($query, $limit = 10)
    {
        return [];
    }

}
