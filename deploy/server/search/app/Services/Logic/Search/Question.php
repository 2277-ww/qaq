<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Services\Logic\Search;

use App\Library\Paginator\Query as PagerQuery;

class Question extends Handler
{

    public function search()
    {
        $pagerQuery = new PagerQuery();

        $params = $pagerQuery->getParams();
        $page = $pagerQuery->getPage();
        $limit = $pagerQuery->getLimit();

        $keyword = $this->handleKeywords($params['query'] ?? '');

        $terms = $this->searchableTerms($this->splitKeywords($keyword));

        $phql = 'SELECT q.id, q.title, q.cover, q.summary, q.tags, q.keywords,'
            . ' q.category_id, q.owner_id, q.bounty, q.anonymous, q.solved,'
            . ' q.create_time, q.last_reply_time, q.view_count, q.like_count,'
            . ' q.answer_count, q.comment_count, q.favorite_count'
            . ' FROM App\Models\Question q'
            . ' WHERE q.deleted = 0 AND q.published = 1';

        $binds = [];

        $fields = ['title', 'summary', 'keywords', 'tags'];

        foreach ($terms as $index => $term) {
            $phql .= ' AND ' . $this->termCondition('q', $fields, $term, $binds);
        }

        $phql .= ' ORDER BY q.id DESC';

        $rows = $this->modelsManager->executeQuery($phql, $binds)->toArray();

        $totalItems = count($rows);

        $rows = $this->sliceRows($rows, $page, $limit);

        $categoryMap = $this->getCategoryMap(array_column($rows, 'category_id'));
        $ownerMap = $this->getUserMap(array_column($rows, 'owner_id'));

        $items = [];

        foreach ($rows as $row) {

            $categoryId = (int)$row['category_id'];
            $ownerId = (int)$row['owner_id'];

            $category = $categoryMap[$categoryId] ?? ['id' => $categoryId, 'name' => '未分类'];
            $owner = $ownerMap[$ownerId] ?? ['id' => $ownerId, 'name' => '匿名用户'];

            $items[] = [
                'id' => (int)$row['id'],
                'title' => $this->highlight($row['title'], $terms),
                'cover' => $this->coverUrl($row['cover']),
                'summary' => $this->highlight($row['summary'], $terms),
                'bounty' => (int)$row['bounty'],
                'anonymous' => (int)$row['anonymous'],
                'solved' => (int)$row['solved'],
                'create_time' => (int)$row['create_time'],
                'last_reply_time' => (int)$row['last_reply_time'],
                'view_count' => (int)$row['view_count'],
                'like_count' => (int)$row['like_count'],
                'answer_count' => (int)$row['answer_count'],
                'comment_count' => (int)$row['comment_count'],
                'favorite_count' => (int)$row['favorite_count'],
                'accept_answer' => null,
                'last_answer' => null,
                'last_replier' => null,
                'category' => $category,
                'owner' => $owner,
                'tags' => $this->decodeJson($row['tags']),
            ];
        }

        return $this->makePager($items, $totalItems, $page, $limit);
    }

    public function getHotQuery($limit = 10, $type = 'total')
    {
        return [];
    }

    public function getRelatedQuery($query, $limit = 10)
    {
        return [];
    }

}
