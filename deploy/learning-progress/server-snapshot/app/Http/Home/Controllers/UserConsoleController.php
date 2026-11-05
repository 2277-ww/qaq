<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Http\Home\Controllers;

use App\Services\Logic\Growth\Profile as GrowthProfileService;
use App\Services\Logic\Growth\Sync as GrowthSyncService;
use App\Services\Logic\Learning\Progress as LearningProgressService;
use App\Services\Logic\Learning\Sync as LearningSyncService;
use App\Services\Logic\Note\NoteList as NoteListService;
use App\Services\Logic\User\Console\AnswerList as AnswerListService;
use App\Services\Logic\User\Console\ArticleList as ArticleListService;
use App\Services\Logic\User\Console\ConsultList as ConsultListService;
use App\Services\Logic\User\Console\ContactInfo as ContactInfoService;
use App\Services\Logic\User\Console\ContactUpdate as ContactUpdateService;
use App\Services\Logic\User\Console\CourseList as CourseListService;
use App\Services\Logic\User\Console\FavoriteList as FavoriteListService;
use App\Services\Logic\User\Console\NotificationList as NotificationListService;
use App\Services\Logic\User\Console\NotificationRead as NotificationReadService;
use App\Services\Logic\User\Console\NotifyStats as NotifyStatsService;
use App\Services\Logic\User\Console\Online as OnlineService;
use App\Services\Logic\User\Console\OrderList as OrderListService;
use App\Services\Logic\User\Console\PointGiftRedeemList as PointGiftRedeemListService;
use App\Services\Logic\User\Console\PointHistory as PointHistoryService;
use App\Services\Logic\User\Console\ProfileInfo as ProfileInfoService;
use App\Services\Logic\User\Console\ProfileUpdate as ProfileUpdateService;
use App\Services\Logic\User\Console\QuestionList as QuestionListService;
use App\Services\Logic\User\Console\RefundList as RefundListService;
use App\Services\Logic\User\Console\ReviewList as ReviewListService;

/**
 * @RoutePrefix("/uc")
 */
class UserConsoleController extends Controller
{

    public function initialize()
    {
        parent::initialize();

        $authUser = $this->getAuthUser(false);

        $this->seo->prependTitle('用户中心');

        $this->view->setVar('auth_user', $authUser);
    }

    /**
     * @Get("/", name="home.uc.index")
     */
    public function indexAction()
    {
        $this->dispatcher->forward(['action' => 'courses']);
    }

    /**
     * @Get("/profile", name="home.uc.profile")
     */
    public function profileAction()
    {
        $service = new ProfileInfoService();

        $user = $service->handle();

        $this->view->pick('user/console/profile');
        $this->view->setVar('user', $user);
    }

    /**
     * @Get("/contact", name="home.uc.contact")
     */
    public function contactAction()
    {
        $service = new ContactInfoService();

        $contact = $service->handle();

        $this->view->pick('user/console/contact');
        $this->view->setVar('contact', $contact);
    }

    /**
     * @Get("/courses", name="home.uc.courses")
     */
    public function coursesAction()
    {
        $service = new CourseListService();

        $pager = $service->handle();

        $this->view->pick('user/console/courses');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/articles", name="home.uc.articles")
     */
    public function articlesAction()
    {
        $service = new ArticleListService();

        $pager = $service->handle();

        $this->view->pick('user/console/articles');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/questions", name="home.uc.questions")
     */
    public function questionsAction()
    {
        $service = new QuestionListService();

        $pager = $service->handle();

        $this->view->pick('user/console/questions');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/answers", name="home.uc.answers")
     */
    public function answersAction()
    {
        $service = new AnswerListService();

        $pager = $service->handle();

        $this->view->pick('user/console/answers');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/favorites", name="home.uc.favorites")
     */
    public function favoritesAction()
    {
        $service = new FavoriteListService();

        $pager = $service->handle();

        $this->view->pick('user/console/favorites');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/notes", name="home.uc.notes")
     */
    public function notesAction()
    {
        $service = new NoteListService();

        $pager = $service->handle();

        $this->view->pick('user/console/notes');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/growth", name="home.uc.growth")
     */
    public function growthAction()
    {
        $service = new GrowthProfileService();

        $profile = $service->handle();

        $this->seo->prependTitle('个人成长档案');

        $this->view->pick('user/console/growth');
        $this->view->setVar('profile', $profile);
    }

    /**
     * @Post("/growth/sync", name="home.uc.growth_sync")
     */
    public function growthSyncAction()
    {
        $service = new GrowthSyncService();

        $result = $service->handle();

        $msg = sprintf('已同步 %d 条事件', $result['sent']);

        return $this->jsonSuccess(['data' => $result, 'msg' => $msg]);
    }

    /**
     * @Get("/progress", name="home.uc.progress")
     */
    public function progressAction()
    {
        $service = new LearningProgressService();

        $progress = $service->handle();

        $this->seo->prependTitle('学习进度');

        $this->view->pick('user/console/progress');
        $this->view->setVar('progress', $progress);
    }

    /**
     * @Post("/progress/sync", name="home.uc.progress_sync")
     */
    public function progressSyncAction()
    {
        $courseId = (int)$this->request->getPost('course_id', 'int', 0);

        $service = new LearningSyncService();

        $result = $courseId > 0 ? $service->pushCourse($courseId) : $service->handle();

        if ($result['dead'] > 0) {
            $msg = sprintf('已推送 %d 条，%d 条失败待排查', $result['sent'], $result['dead']);
        } elseif ($result['sent'] > 0) {
            $msg = sprintf('已推送 %d 条学习进度到考试平台', $result['sent']);
        } else {
            $msg = '当前进度已是最新，无需重复推送';
        }

        return $this->jsonSuccess(['data' => $result, 'msg' => $msg]);
    }

    /**
     * @Get("/consults", name="home.uc.consults")
     */
    public function consultsAction()
    {
        $service = new ConsultListService();

        $pager = $service->handle();

        $this->view->pick('user/console/consults');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/reviews", name="home.uc.reviews")
     */
    public function reviewsAction()
    {
        $service = new ReviewListService();

        $pager = $service->handle();

        $this->view->pick('user/console/reviews');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/orders", name="home.uc.orders")
     */
    public function ordersAction()
    {
        $service = new OrderListService();

        $pager = $service->handle();

        $this->view->pick('user/console/orders');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/refunds", name="home.uc.refunds")
     */
    public function refundsAction()
    {
        $service = new RefundListService();

        $pager = $service->handle();

        $this->view->pick('user/console/refunds');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/point/history", name="home.uc.point_history")
     */
    public function pointHistoryAction()
    {
        $service = new PointHistoryService();

        $pager = $service->handle();

        $this->view->pick('user/console/point_history');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/point/gift/redeems", name="home.uc.point_gift_redeems")
     */
    public function pointGiftRedeemsAction()
    {
        $service = new PointGiftRedeemListService();

        $pager = $service->handle();

        $this->view->pick('user/console/point_gift_redeems');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/notifications", name="home.uc.notifications")
     */
    public function notificationsAction()
    {
        $service = new NotificationListService();

        $pager = $service->handle();

        $service = new NotificationReadService();

        $service->handle();

        $this->view->pick('user/console/notifications');
        $this->view->setVar('pager', $pager);
    }

    /**
     * @Get("/notify/stats", name="home.uc.notify_stats")
     */
    public function notifyStatsAction()
    {
        $service = new NotifyStatsService();

        $stats = $service->handle();

        return $this->jsonSuccess(['stats' => $stats]);
    }

    /**
     * @Post("/profile/update", name="home.uc.update_profile")
     */
    public function updateProfileAction()
    {
        $service = new ProfileUpdateService();

        $service->handle();

        $location = $this->url->get(['for' => 'home.uc.profile']);

        $content = [
            'location' => $location,
            'msg' => '更新资料成功',
        ];

        return $this->jsonSuccess($content);
    }

    /**
     * @Post("/contact/update", name="home.uc.update_contact")
     */
    public function updateContactAction()
    {
        $service = new ContactUpdateService();

        $service->handle();

        $content = ['msg' => '更新收货信息成功'];

        return $this->jsonSuccess($content);
    }

    /**
     * @Post("/online", name="home.uc.online")
     */
    public function onlineAction()
    {
        $service = new OnlineService();

        $service->handle();

        return $this->jsonSuccess();
    }

}
