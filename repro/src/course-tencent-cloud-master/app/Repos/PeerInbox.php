<?php
/**
 * 跨平台入站事件收件箱仓储
 */

namespace App\Repos;

use App\Models\PeerInbox as PeerInboxModel;

class PeerInbox extends Repository
{

    /**
     * @param string $source
     * @param string $eventId
     * @return PeerInboxModel|\Phalcon\Mvc\Model|bool
     */
    public function findByEventId($source, $eventId)
    {
        return PeerInboxModel::findFirst([
            'conditions' => 'source = :source: AND event_id = :event_id:',
            'bind' => ['source' => $source, 'event_id' => $eventId],
        ]);
    }

    /**
     * 待处理事件（供后续的处理器消费）
     *
     * @param string $source 留空表示全部来源
     * @param int $limit
     * @return PeerInboxModel[]
     */
    public function findPending($source = '', $limit = 100)
    {
        $conditions = 'status = :status:';
        $bind = ['status' => PeerInboxModel::STATUS_RECEIVED];

        if ($source !== '') {
            $conditions .= ' AND source = :source:';
            $bind['source'] = $source;
        }

        return PeerInboxModel::find([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id ASC',
            'limit' => $limit,
        ]);
    }

    /**
     * @param string $source 留空表示全部来源
     * @return int
     */
    public function countPending($source = '')
    {
        $conditions = 'status = :status:';
        $bind = ['status' => PeerInboxModel::STATUS_RECEIVED];

        if ($source !== '') {
            $conditions .= ' AND source = :source:';
            $bind['source'] = $source;
        }

        return (int)PeerInboxModel::count([
            'conditions' => $conditions,
            'bind' => $bind,
        ]);
    }

}
