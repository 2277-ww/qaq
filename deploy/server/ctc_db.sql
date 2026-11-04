-- MySQL dump 10.13  Distrib 5.7.38, for Win64 (x86_64)
--
-- Host: localhost    Database: ctc
-- ------------------------------------------------------
-- Server version	5.7.38

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `kg_account`
--

DROP TABLE IF EXISTS `kg_account`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_account` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `email` varchar(30) NOT NULL DEFAULT '' COMMENT '邮箱',
  `phone` varchar(30) NOT NULL DEFAULT '' COMMENT '手机',
  `password` varchar(32) NOT NULL DEFAULT '' COMMENT '密码',
  `salt` varchar(32) NOT NULL DEFAULT '' COMMENT '密盐',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `email` (`email`),
  KEY `phone` (`phone`)
) ENGINE=InnoDB AUTO_INCREMENT=20001 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_account`
--

LOCK TABLES `kg_account` WRITE;
/*!40000 ALTER TABLE `kg_account` DISABLE KEYS */;
INSERT INTO `kg_account` VALUES (10000,'10000@163.com','','895a4bad82ceff37f8415b39c0a17adc','YICoXLFd',0,1793683908,1793684100),(20000,'audit20000@test.com','','22525b5b53722fa59b95cba2bc1785d8','testSlt8',0,1793691085,1793691085);
/*!40000 ALTER TABLE `kg_account` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_answer`
--

DROP TABLE IF EXISTS `kg_answer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_answer` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `question_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '问题编号',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '概要',
  `content` text NOT NULL COMMENT '内容',
  `anonymous` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '匿名标识',
  `accepted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '采纳标识',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `comment_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评论数',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `owner_id` (`owner_id`),
  KEY `question_id` (`question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_answer`
--

LOCK TABLES `kg_answer` WRITE;
/*!40000 ALTER TABLE `kg_answer` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_answer` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_answer_like`
--

DROP TABLE IF EXISTS `kg_answer_like`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_answer_like` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `answer_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '答案编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `answer_user` (`answer_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_answer_like`
--

LOCK TABLES `kg_answer_like` WRITE;
/*!40000 ALTER TABLE `kg_answer_like` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_answer_like` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_article`
--

DROP TABLE IF EXISTS `kg_article`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_article` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '摘要',
  `keywords` varchar(100) NOT NULL DEFAULT '' COMMENT '关键字',
  `tags` varchar(255) NOT NULL DEFAULT '[]' COMMENT '标签',
  `content` text NOT NULL COMMENT '内容',
  `score` float NOT NULL DEFAULT '0' COMMENT '综合得分',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '分类编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `source_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '来源类型',
  `source_url` varchar(100) NOT NULL DEFAULT '' COMMENT '来源网址',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `featured` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '推荐标识',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `closed` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '关闭标识',
  `word_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '文字数',
  `view_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '浏览数',
  `comment_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评论数',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `favorite_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '收藏数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  KEY `owner_id` (`owner_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_article`
--

LOCK TABLES `kg_article` WRITE;
/*!40000 ALTER TABLE `kg_article` DISABLE KEYS */;
INSERT INTO `kg_article` VALUES (1,'wwwww','','wwweeeerrt','','[]','<p>wwweeeerrt</p>',0,0,10000,1,'',1,'127.0.0.1',0,1,0,0,1,0,0,0,0,0,1793772122,1793772122);
/*!40000 ALTER TABLE `kg_article` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_article_favorite`
--

DROP TABLE IF EXISTS `kg_article_favorite`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_article_favorite` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `article_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '文章编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_article_favorite`
--

LOCK TABLES `kg_article_favorite` WRITE;
/*!40000 ALTER TABLE `kg_article_favorite` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_article_favorite` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_article_like`
--

DROP TABLE IF EXISTS `kg_article_like`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_article_like` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `article_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '文章编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `article_user` (`article_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_article_like`
--

LOCK TABLES `kg_article_like` WRITE;
/*!40000 ALTER TABLE `kg_article_like` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_article_like` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_article_tag`
--

DROP TABLE IF EXISTS `kg_article_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_article_tag` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `article_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '文章编号',
  `tag_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`),
  KEY `tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_article_tag`
--

LOCK TABLES `kg_article_tag` WRITE;
/*!40000 ALTER TABLE `kg_article_tag` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_article_tag` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_audit`
--

DROP TABLE IF EXISTS `kg_audit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_audit` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `user_name` varchar(30) NOT NULL DEFAULT '' COMMENT '用户名称',
  `user_ip` varchar(30) NOT NULL DEFAULT '' COMMENT '用户IP',
  `req_route` varchar(50) NOT NULL DEFAULT '' COMMENT '请求路由',
  `req_path` varchar(100) NOT NULL DEFAULT '' COMMENT '请求路径',
  `req_data` text NOT NULL COMMENT '请求数据',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_audit`
--

LOCK TABLES `kg_audit` WRITE;
/*!40000 ALTER TABLE `kg_audit` DISABLE KEYS */;
INSERT INTO `kg_audit` VALUES (1,10000,'酷瓜云课堂','127.0.0.1','admin.vod_sync.run','/admin/vod_sync/run','{\"source_id\":\"0\"}',1793750413),(2,10000,'酷瓜云课堂','127.0.0.1','admin.vod_sync.run','/admin/vod_sync/run','{\"source_id\":\"0\"}',1793750454);
/*!40000 ALTER TABLE `kg_audit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_category`
--

DROP TABLE IF EXISTS `kg_category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_category` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `parent_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '父级编号',
  `level` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '层级',
  `type` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '类型',
  `name` varchar(30) NOT NULL DEFAULT '' COMMENT '名称',
  `icon` varchar(100) NOT NULL DEFAULT '' COMMENT '图标',
  `alias` varchar(30) NOT NULL DEFAULT '' COMMENT '别名',
  `path` varchar(30) NOT NULL DEFAULT '' COMMENT '路径',
  `priority` int(11) unsigned NOT NULL DEFAULT '30' COMMENT '优先级',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `child_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '节点数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_category`
--

LOCK TABLES `kg_category` WRITE;
/*!40000 ALTER TABLE `kg_category` DISABLE KEYS */;
INSERT INTO `kg_category` VALUES (1,0,1,1,'前端开发','/img/default/category_icon.png','frontend','frontend',100,1,0,0,1793684217,0),(2,0,1,1,'Python 与算法','/img/default/category_icon.png','python','python',99,1,0,0,1793684217,0),(3,0,1,1,'计算机视觉','/img/default/category_icon.png','vision','vision',98,1,0,0,1793684217,0),(4,0,1,1,'容器与部署','/img/default/category_icon.png','devops','devops',97,1,0,0,1793684217,0),(5,0,1,1,'数据库','/img/default/category_icon.png','database','database',96,1,0,0,1793684217,0),(6,0,1,1,'网络安全','/img/default/category_icon.png','security','security',95,1,0,0,1793684217,0),(7,0,1,1,'警务业务知识','/img/default/category_icon.png','police','police',94,1,0,0,1793693197,1793693197);
/*!40000 ALTER TABLE `kg_category` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter`
--

DROP TABLE IF EXISTS `kg_chapter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `parent_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '父级编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `priority` int(11) unsigned NOT NULL DEFAULT '30' COMMENT '优先级',
  `free` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '免费标识',
  `model` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '模式类型',
  `attrs` varchar(1000) NOT NULL DEFAULT '' COMMENT '扩展属性',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `lesson_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课时数',
  `user_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学员数',
  `comment_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评论数',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `parent_id` (`parent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter`
--

LOCK TABLES `kg_chapter` WRITE;
/*!40000 ALTER TABLE `kg_chapter` DISABLE KEYS */;
INSERT INTO `kg_chapter` VALUES (1,0,1,'第一章 结构与样式','',1,1,1,'[]',1,0,2,1,0,0,1793684217,1793691120),(2,1,1,'页面骨架与语义化标签','',2,1,1,'{\"duration\":337,\"file\":{\"status\":\"pending\"}}',1,0,0,1,0,0,1793684217,1793708911),(3,1,1,'盒模型与页面布局','',3,1,1,'{\"duration\":374,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684217,1793757231),(4,0,1,'第二章 交互与工程化','',4,1,1,'[]',1,0,2,0,0,0,1793684217,0),(5,4,1,'DOM 事件与网页交互','',5,1,1,'{\"duration\":411,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684217,1793757231),(6,4,1,'模块化与构建工具','',6,1,1,'{\"duration\":448,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684217,1793708911),(7,0,2,'第一章 排序算法','',7,1,1,'[]',1,0,2,0,0,0,1793684217,1793757231),(8,7,2,'排序算法稳定性与复杂度','',8,1,1,'{\"duration\":485,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684217,1793757231),(9,7,2,'冒泡排序思路与代码实现','',9,1,1,'{\"duration\":522,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684217,1793757231),(10,0,2,'第二章 查找与进阶算法','',10,1,1,'[]',1,0,2,0,0,0,1793684217,1793757231),(11,10,2,'二分查找：递归与迭代','',11,1,1,'{\"duration\":559,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684217,1793757231),(12,10,2,'快速排序图解与实现','',12,1,1,'{\"duration\":596,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684218,1793757231),(13,0,3,'第一章 数据与标注','',13,1,1,'[]',1,0,2,0,0,0,1793684218,0),(14,13,3,'数据集组织规范','',14,1,1,'{\"duration\":333,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684218,1793708911),(15,13,3,'标注工具与质量控制','',15,1,1,'{\"duration\":370,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684218,1793708911),(16,0,3,'第二章 训练与推理','',16,1,1,'[]',1,0,2,0,0,0,1793684218,0),(17,16,3,'训练参数与指标解读','',17,1,1,'{\"duration\":407,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684218,1793708911),(18,16,3,'推理服务封装','',18,1,1,'{\"duration\":444,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684218,1793708911),(19,0,4,'第一章 镜像与容器','',19,1,1,'[]',1,0,2,0,0,0,1793684219,0),(20,19,4,'Dockerfile 编写要点','',20,1,1,'{\"duration\":481,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684219,1793708911),(21,19,4,'镜像分层与体积优化','',21,1,1,'{\"duration\":518,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684219,1793708911),(22,0,4,'第二章 编排与运维','',22,1,1,'[]',1,0,2,0,0,0,1793684219,0),(23,22,4,'Compose 多服务编排','',23,1,1,'{\"duration\":555,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684219,1793708911),(24,22,4,'容器化部署实战：MySQL','',24,1,1,'{\"duration\":592,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684220,1793757231),(25,0,5,'第一章 建模与索引','',25,1,1,'[]',1,0,2,1,0,0,1793684220,1793753900),(26,25,5,'范式与表结构设计','',26,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,1,0,0,1793684220,1793753900),(27,25,5,'B+ 树索引原理','',27,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684220,0),(28,0,5,'第二章 事务与优化','',28,1,1,'[]',1,0,2,0,0,0,1793684220,0),(29,28,5,'事务隔离级别','',29,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684221,0),(30,28,5,'慢查询分析与优化','',30,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684221,0),(31,0,6,'第一章 安全基础','',31,1,1,'[]',1,0,2,1,0,0,1793684221,1793757231),(32,31,6,'网络安全基础概念','',32,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,1,0,0,1793684221,1793757231),(33,31,6,'计算机病毒与木马','',33,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684222,1793757231),(34,0,6,'第二章 Web 攻击与检测','',34,1,1,'[]',1,0,2,0,0,0,1793684222,1793757231),(35,34,6,'XSS 攻击与检测','',35,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684222,1793757231),(36,34,6,'SQL 注入与防护','',36,1,1,'{\"duration\":0,\"file\":{\"status\":\"pending\"}}',1,0,0,0,0,0,1793684222,1793757231),(37,0,7,'第一章 开发环境','',30,0,1,'[]',1,1,0,2,0,0,1793750309,1793753947),(38,37,7,'环境搭建与工具链入门','从零搭建 Python 开发环境，介绍常用工具链。',30,1,1,'{\"duration\":1250,\"file\":{\"status\":\"uploaded\"}}',1,1,0,1,0,0,1793750309,1793750377),(39,37,7,'虚拟环境与依赖管理','venv、pip 与 requirements 的最佳实践。',60,1,1,'{\"duration\":980,\"file\":{\"status\":\"uploaded\"}}',1,1,0,1,0,0,1793750309,1793753947),(40,0,7,'第二章 语言进阶','',60,0,1,'[]',1,1,0,0,0,0,1793750309,0),(41,40,7,'列表推导与生成器表达式','深入理解 Pythonic 的迭代构造方式。',30,1,1,'{\"duration\":1500,\"file\":{\"status\":\"uploaded\"}}',1,1,0,0,0,0,1793750309,0),(42,40,7,'并发编程：从线程到协程','',60,1,1,'{\"duration\":2400,\"file\":{\"status\":\"uploaded\"}}',1,1,0,0,0,0,1793750309,0),(43,0,8,'同步资源','',30,0,1,'[]',1,1,0,1,0,0,1793750310,1793753962),(44,43,8,'未指定分类的条目走源默认分类','',30,1,1,'{\"duration\":660,\"file\":{\"status\":\"uploaded\"}}',1,1,0,1,0,0,1793750310,1793753962),(45,0,9,'第一章 刑法基础','',30,0,1,'[]',1,0,0,1,0,0,1793757242,1793757443),(46,45,9,'刑法概述与基本原则','刑法的性质、任务与基本原则，公安执法中的刑法适用基础。',30,1,1,'{\"duration\":1023,\"file\":{\"status\":\"uploaded\"}}',1,0,0,1,0,0,1793757242,1793757443),(47,45,9,'犯罪构成与认定','犯罪构成四要件与认定方法，常见罪名分析思路。',60,1,1,'{\"duration\":3624,\"file\":{\"status\":\"uploaded\"}}',1,0,0,0,0,0,1793757243,0),(48,0,9,'第二章 行政执法实务','',60,0,1,'[]',1,0,0,0,0,0,1793757243,0),(49,48,9,'行政处罚法要点','行政处罚的种类、程序与执法规范要点。',30,1,1,'{\"duration\":3237,\"file\":{\"status\":\"uploaded\"}}',1,0,0,0,0,0,1793757243,0),(50,48,9,'治安管理处罚法（分则）','扰乱公共秩序等常见治安违法行为的认定与处罚。',60,1,1,'{\"duration\":3026,\"file\":{\"status\":\"uploaded\"}}',1,0,0,0,0,0,1793757243,0);
/*!40000 ALTER TABLE `kg_chapter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_favorite`
--

DROP TABLE IF EXISTS `kg_chapter_favorite`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_favorite` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课时编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '收藏时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_favorite_user_chapter` (`user_id`,`chapter_id`),
  KEY `idx_favorite_chapter` (`chapter_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COMMENT='收藏视频';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_favorite`
--

LOCK TABLES `kg_chapter_favorite` WRITE;
/*!40000 ALTER TABLE `kg_chapter_favorite` DISABLE KEYS */;
INSERT INTO `kg_chapter_favorite` VALUES (1,1,3,10000,0,1793708912,0),(2,1,5,10000,0,1793708912,0),(3,2,9,10000,1,1793708912,1793754043);
/*!40000 ALTER TABLE `kg_chapter_favorite` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_like`
--

DROP TABLE IF EXISTS `kg_chapter_like`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_like` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `chapter_user` (`chapter_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_like`
--

LOCK TABLES `kg_chapter_like` WRITE;
/*!40000 ALTER TABLE `kg_chapter_like` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_chapter_like` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_live`
--

DROP TABLE IF EXISTS `kg_chapter_live`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_live` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '章节编号',
  `start_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间',
  `user_limit` int(11) unsigned NOT NULL DEFAULT '100' COMMENT '用户限额',
  `status` int(11) unsigned NOT NULL DEFAULT '2' COMMENT '状态标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `chapter_id` (`chapter_id`),
  KEY `course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_live`
--

LOCK TABLES `kg_chapter_live` WRITE;
/*!40000 ALTER TABLE `kg_chapter_live` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_chapter_live` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_offline`
--

DROP TABLE IF EXISTS `kg_chapter_offline`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_offline` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '章节编号',
  `start_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `chapter_id` (`chapter_id`),
  KEY `course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_offline`
--

LOCK TABLES `kg_chapter_offline` WRITE;
/*!40000 ALTER TABLE `kg_chapter_offline` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_chapter_offline` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_read`
--

DROP TABLE IF EXISTS `kg_chapter_read`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_read` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '章节编号',
  `content` text NOT NULL COMMENT '内容',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `chapter_id` (`chapter_id`),
  KEY `course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_read`
--

LOCK TABLES `kg_chapter_read` WRITE;
/*!40000 ALTER TABLE `kg_chapter_read` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_chapter_read` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_user`
--

DROP TABLE IF EXISTS `kg_chapter_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '章节编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `plan_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '计划编号',
  `duration` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习时长',
  `position` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '播放位置',
  `progress` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习进度',
  `consumed` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '消费标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `active_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '活跃时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `status` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习状态 0 未开始 1 学习中 2 已完成',
  `first_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '首次学习时间',
  `complete_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '完成时间',
  `scroll` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '图文最大滚动百分比',
  `dwell` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '图文累计停留秒数',
  PRIMARY KEY (`id`),
  KEY `chapter_user` (`chapter_id`,`user_id`),
  KEY `course_user` (`course_id`,`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_user`
--

LOCK TABLES `kg_chapter_user` WRITE;
/*!40000 ALTER TABLE `kg_chapter_user` DISABLE KEYS */;
INSERT INTO `kg_chapter_user` VALUES (1,1,2,20000,20261103,0,0,0,0,0,0,1793691120,0,0,0,0,0,0),(2,1,2,10000,20261103,324,0,100,1,0,1793622510,1793708911,0,2,1793608110,1793622510,0,0),(3,1,3,10000,20261103,359,0,100,1,0,1793626110,1793708911,0,2,1793611710,1793626110,0,0),(4,1,5,10000,20261103,395,0,100,1,0,1793629710,1793708911,0,2,1793615310,1793629710,0,0),(5,1,6,10000,20261103,430,0,100,1,0,1793633310,1793708911,0,2,1793618910,1793633310,0,0),(6,2,8,10000,20261103,466,0,100,1,0,1793622510,1793708911,0,2,1793608110,1793622510,0,0),(7,2,9,10000,20261103,501,0,100,1,0,1793626110,1793708911,0,2,1793611710,1793626110,0,0),(8,2,11,10000,20261103,537,0,100,1,0,1793629710,1793708911,0,2,1793615310,1793629710,0,0),(9,2,12,10000,20261103,310,30,52,1,0,1793705910,1793708911,1793709367,2,1793687310,1793709366,0,0),(10,3,14,10000,20261103,320,0,100,1,0,1793622510,1793708911,0,2,1793608110,1793622510,0,0),(11,3,15,10000,20261103,355,0,100,1,0,1793626110,1793708911,0,2,1793611710,1793626110,0,0),(12,3,17,10000,20261103,171,179,42,0,0,1793706510,1793708911,0,1,1793687310,0,0,0),(13,3,18,10000,20261103,80,89,18,0,0,1793705910,1793708911,0,1,1793687310,0,0,0),(14,4,20,10000,20261103,462,0,100,1,0,1793622510,1793708911,0,2,1793608110,1793622510,0,0),(15,4,21,10000,20261103,218,228,42,0,0,1793707110,1793708911,0,1,1793687310,0,0,0),(16,4,23,10000,20261103,100,111,18,0,0,1793706510,1793708911,0,1,1793687310,0,0,0),(17,4,24,10000,20261103,107,118,18,0,0,1793705910,1793708911,0,1,1793687310,0,0,0),(19,6,32,10000,20261104,0,0,0,0,0,0,1793753815,0,0,0,0,0,0),(20,5,26,10000,20261104,0,0,0,0,0,0,1793753900,0,0,0,0,0,0),(23,9,46,10000,20261104,0,0,0,0,0,0,1793757443,0,0,0,0,0,0);
/*!40000 ALTER TABLE `kg_chapter_user` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_chapter_vod`
--

DROP TABLE IF EXISTS `kg_chapter_vod`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_chapter_vod` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '章节编号',
  `file_id` varchar(32) NOT NULL DEFAULT '' COMMENT '文件编号',
  `file_transcode` varchar(1500) NOT NULL DEFAULT '' COMMENT '文件属性',
  `file_remote` varchar(1500) NOT NULL DEFAULT '' COMMENT '远程资源',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `chapter_id` (`chapter_id`),
  KEY `course_id` (`course_id`),
  KEY `file_id` (`file_id`)
) ENGINE=InnoDB AUTO_INCREMENT=58 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_chapter_vod`
--

LOCK TABLES `kg_chapter_vod` WRITE;
/*!40000 ALTER TABLE `kg_chapter_vod` DISABLE KEYS */;
INSERT INTO `kg_chapter_vod` VALUES (1,1,2,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/semantic-html.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/semantic-html.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/semantic-html.mp4\"}}',1793684217,1793757231),(3,1,3,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/box-model.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/box-model.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/box-model.mp4\"}}',1793684217,1793757231),(5,1,5,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/dom-event.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/dom-event.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/dom-event.mp4\"}}',1793684217,1793757231),(7,1,6,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/webpack.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/webpack.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/frontend/webpack.mp4\"}}',1793684217,1793757231),(9,2,8,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/sort-stability.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/sort-stability.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/sort-stability.mp4\"}}',1793684217,1793757231),(11,2,9,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/bubble-sort.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/bubble-sort.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/bubble-sort.mp4\"}}',1793684217,1793757231),(13,2,11,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/binary-search.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/binary-search.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/binary-search.mp4\"}}',1793684217,1793757231),(15,2,12,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/quick-sort.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/quick-sort.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/python/quick-sort.mp4\"}}',1793684218,1793757231),(17,3,14,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/dataset-build.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/dataset-build.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/dataset-build.mp4\"}}',1793684218,1793757231),(19,3,15,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/labeling.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/labeling.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/labeling.mp4\"}}',1793684218,1793757231),(21,3,17,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/train-metrics.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/train-metrics.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/train-metrics.mp4\"}}',1793684218,1793757231),(23,3,18,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/inference.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/inference.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/vision/inference.mp4\"}}',1793684219,1793757231),(25,4,20,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/dockerfile.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/dockerfile.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/dockerfile.mp4\"}}',1793684219,1793757231),(27,4,21,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/image-layer.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/image-layer.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/image-layer.mp4\"}}',1793684219,1793757231),(29,4,23,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/compose.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/compose.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/compose.mp4\"}}',1793684219,1793757231),(31,4,24,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/deploy-mysql.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/deploy-mysql.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/devops/deploy-mysql.mp4\"}}',1793684220,1793757231),(33,5,26,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/table-design.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/table-design.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/table-design.mp4\"}}',1793684220,1793757231),(35,5,27,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/btree-index.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/btree-index.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/btree-index.mp4\"}}',1793684220,1793757231),(37,5,29,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/isolation.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/isolation.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/isolation.mp4\"}}',1793684221,1793757231),(39,5,30,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/slow-query.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/slow-query.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/database/slow-query.mp4\"}}',1793684221,1793757231),(41,6,32,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/security-basics.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/security-basics.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/security-basics.mp4\"}}',1793684221,1793757231),(43,6,33,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/virus-trojan.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/virus-trojan.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/virus-trojan.mp4\"}}',1793684222,1793757231),(45,6,35,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/xss.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/xss.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/xss.mp4\"}}',1793684222,1793757231),(47,6,36,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/sqli.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/sqli.mp4\"},\"fd\":{\"url\":\"http://127.0.0.1:8000/static/vod/security/sqli.mp4\"}}',1793684222,1793757231),(54,9,46,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/criminal-law-intro.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/criminal-law-intro.mp4\"},\"fd\":{\"url\":\"\"}}',1793757242,1793757242),(55,9,47,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/crime-constitution.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/crime-constitution.mp4\"},\"fd\":{\"url\":\"\"}}',1793757243,1793757243),(56,9,49,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/admin-penalty.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/admin-penalty.mp4\"},\"fd\":{\"url\":\"\"}}',1793757243,1793757243),(57,9,50,'','[]','{\"hd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/public-order.mp4\"},\"sd\":{\"url\":\"http://127.0.0.1:8000/static/vod/police/public-order.mp4\"},\"fd\":{\"url\":\"\"}}',1793757243,1793757243);
/*!40000 ALTER TABLE `kg_chapter_vod` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_comment`
--

DROP TABLE IF EXISTS `kg_comment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_comment` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `content` varchar(1000) NOT NULL DEFAULT '' COMMENT '内容',
  `parent_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '父级编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `to_user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '回复用户',
  `item_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目编号',
  `item_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目类型',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `reply_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '回复数',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `item` (`item_id`,`item_type`),
  KEY `owner_id` (`owner_id`),
  KEY `parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_comment`
--

LOCK TABLES `kg_comment` WRITE;
/*!40000 ALTER TABLE `kg_comment` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_comment` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_comment_like`
--

DROP TABLE IF EXISTS `kg_comment_like`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_comment_like` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `comment_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评论编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `comment_user` (`comment_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_comment_like`
--

LOCK TABLES `kg_comment_like` WRITE;
/*!40000 ALTER TABLE `kg_comment_like` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_comment_like` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_connect`
--

DROP TABLE IF EXISTS `kg_connect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_connect` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `union_id` varchar(64) NOT NULL DEFAULT '' COMMENT 'union_id',
  `open_id` varchar(64) NOT NULL DEFAULT '' COMMENT '开放ID',
  `open_name` varchar(30) NOT NULL DEFAULT '' COMMENT '开放名称',
  `open_avatar` varchar(255) NOT NULL DEFAULT '' COMMENT '开放头像',
  `provider` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '提供方',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `open_provider` (`open_id`,`provider`),
  KEY `union_provider` (`union_id`,`provider`),
  KEY `user_id` (`user_id`),
  KEY `open_id` (`open_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_connect`
--

LOCK TABLES `kg_connect` WRITE;
/*!40000 ALTER TABLE `kg_connect` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_connect` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_consult`
--

DROP TABLE IF EXISTS `kg_consult`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_consult` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `replier_id` int(11) NOT NULL DEFAULT '0' COMMENT '回复者编号',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `question` varchar(1500) NOT NULL DEFAULT '' COMMENT '问题',
  `answer` varchar(1500) NOT NULL DEFAULT '' COMMENT '答案',
  `rating` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评分',
  `priority` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '优先级',
  `private` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '私密标识',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `reply_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '回复时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_consult`
--

LOCK TABLES `kg_consult` WRITE;
/*!40000 ALTER TABLE `kg_consult` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_consult` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course`
--

DROP TABLE IF EXISTS `kg_course`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `tags` varchar(255) NOT NULL DEFAULT '[]' COMMENT '标签',
  `keywords` varchar(100) NOT NULL DEFAULT '' COMMENT '关键字',
  `details` text NOT NULL COMMENT '详情',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '分类编号',
  `teacher_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '讲师编号',
  `origin_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '原始价格',
  `market_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '市场价格',
  `vip_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '会员价格',
  `study_expiry` int(11) unsigned NOT NULL DEFAULT '12' COMMENT '学习期限',
  `refund_expiry` int(11) unsigned NOT NULL DEFAULT '30' COMMENT '退款期限',
  `rating` float NOT NULL DEFAULT '5' COMMENT '用户评分',
  `score` float NOT NULL DEFAULT '0' COMMENT '综合得分',
  `model` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '模型',
  `level` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '难度',
  `attrs` varchar(1000) NOT NULL DEFAULT '' COMMENT '扩展属性',
  `featured` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '推荐标识',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `resource_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '资料数',
  `user_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学员数',
  `fake_user_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '伪造用户数',
  `lesson_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课时数',
  `package_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '套餐数',
  `review_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评价数',
  `consult_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '咨询数',
  `favorite_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '收藏数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  KEY `teacher_id` (`teacher_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course`
--

LOCK TABLES `kg_course` WRITE;
/*!40000 ALTER TABLE `kg_course` DISABLE KEYS */;
INSERT INTO `kg_course` VALUES (1,'前端开发实战：从页面到交互','/cover/c1.png','以真实页面为线索，讲清 HTML 结构、CSS 布局与 JavaScript 交互三件事。','[]','前端,HTML,CSS,JavaScript','<p>以真实页面为线索，讲清 HTML 结构、CSS 布局与 JavaScript 交互三件事。</p><p>本课程为本地复现环境生成的演示课程，用于验证课程浏览与学习流程。</p>',1,10000,0.00,0.00,0.00,12,30,5,100,1,1,'{\"duration\":0}',1,1,0,0,1,1,4,0,0,0,1,1793684217,1793712129),(2,'Python 算法入门','/cover/c2.png','从列表、字典到排序与查找，用可运行的例子建立算法思维。','[]','Python,算法,数据结构','<p>从列表、字典到排序与查找，用可运行的例子建立算法思维。</p><p>本课程为本地复现环境生成的演示课程，用于验证课程浏览与学习流程。</p>',2,10000,0.00,0.00,0.00,12,30,5,100,1,1,'{\"duration\":0}',1,1,0,0,0,0,4,0,0,0,0,1793684217,0),(3,'YOLO 目标检测实战','/cover/c3.png','围绕数据集标注、模型训练与推理部署，走通一次完整的目标检测流程。','[]','YOLO,目标检测,视觉','<p>围绕数据集标注、模型训练与推理部署，走通一次完整的目标检测流程。</p><p>本课程为本地复现环境生成的演示课程，用于验证课程浏览与学习流程。</p>',3,10000,0.00,0.00,0.00,12,30,5,100,1,1,'{\"duration\":0}',1,1,0,0,0,0,4,0,0,0,0,1793684218,0),(4,'Docker 容器化部署','/cover/c4.png','从镜像构建到多容器编排，掌握可重复的部署方式。','[]','Docker,容器,部署','<p>从镜像构建到多容器编排，掌握可重复的部署方式。</p><p>本课程为本地复现环境生成的演示课程，用于验证课程浏览与学习流程。</p>',4,10000,0.00,0.00,0.00,12,30,5,100,1,1,'{\"duration\":0}',1,1,0,0,0,0,4,0,0,0,0,1793684219,0),(5,'数据库原理与应用','/cover/c5.png','讲透表设计、索引与事务，让查询跑得更快也更稳。','[]','MySQL,索引,事务','<p>讲透表设计、索引与事务，让查询跑得更快也更稳。</p><p>本课程为本地复现环境生成的演示课程，用于验证课程浏览与学习流程。</p>',5,10000,0.00,0.00,0.00,12,30,5,100,1,1,'{\"duration\":0}',1,1,0,0,1,1,4,0,0,0,1,1793684220,1793753900),(6,'网络安全基础','/cover/c6.png','从常见 Web 漏洞出发，理解攻击路径与防护要点。','[]','网络安全,漏洞,防护','<p>从常见 Web 漏洞出发，理解攻击路径与防护要点。</p><p>本课程为本地复现环境生成的演示课程，用于验证课程浏览与学习流程。</p>',6,10000,0.00,0.00,0.00,12,30,5,100,1,1,'{\"duration\":0}',1,1,0,0,1,1,4,0,0,0,0,1793684221,1793753815),(7,'Python 进阶实战','/img/default/course_cover.png','','[]','','',2,0,0.00,0.00,0.00,12,7,5,0,1,2,'{\"duration\":6130}',0,1,1,0,1,1,0,0,0,0,0,1793750309,1793750377),(8,'前端基础补完计划','/img/default/course_cover.png','','[]','','',2,0,0.00,0.00,0.00,12,7,5,0,1,2,'{\"duration\":660}',0,1,1,0,1,1,0,0,0,0,0,1793750309,1793753962),(9,'公安业务基础知识','/cover/c7.png','公安执法必备的基础法律知识：刑法概述、犯罪构成、行政处罚法与治安管理处罚法，助力警务人员规范执法。','[]','','<p>本课程面向警务人员与公安院校学生，系统讲解执法工作中的基础法律知识。</p><p>第一章 刑法基础：刑法概述与基本原则、犯罪构成与认定。</p><p>第二章 行政执法实务：行政处罚法要点、治安管理处罚法（分则）。</p>',7,0,0.00,0.00,0.00,12,7,5,0,1,2,'{\"duration\":10910}',0,1,0,0,1,1,4,0,0,0,0,1793757242,1793757882);
/*!40000 ALTER TABLE `kg_course` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_favorite`
--

DROP TABLE IF EXISTS `kg_course_favorite`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_favorite` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_favorite`
--

LOCK TABLES `kg_course_favorite` WRITE;
/*!40000 ALTER TABLE `kg_course_favorite` DISABLE KEYS */;
INSERT INTO `kg_course_favorite` VALUES (1,1,20000,0,1793691145,0),(2,1,10000,0,1793708911,1793712129),(3,2,10000,0,1793708911,0),(4,5,10000,0,1793708912,1793709747);
/*!40000 ALTER TABLE `kg_course_favorite` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_package`
--

DROP TABLE IF EXISTS `kg_course_package`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_package` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `package_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '套餐编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `package_id` (`package_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_package`
--

LOCK TABLES `kg_course_package` WRITE;
/*!40000 ALTER TABLE `kg_course_package` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_course_package` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_rating`
--

DROP TABLE IF EXISTS `kg_course_rating`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_rating` (
  `course_id` int(11) unsigned NOT NULL COMMENT '主键编号',
  `rating` float NOT NULL DEFAULT '5' COMMENT '综合评分',
  `rating1` float NOT NULL DEFAULT '5' COMMENT '维度1评分',
  `rating2` float NOT NULL DEFAULT '5' COMMENT '维度2评分',
  `rating3` float NOT NULL DEFAULT '5' COMMENT '维度3评分',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_rating`
--

LOCK TABLES `kg_course_rating` WRITE;
/*!40000 ALTER TABLE `kg_course_rating` DISABLE KEYS */;
INSERT INTO `kg_course_rating` VALUES (1,5,5,5,5,1793684217,0),(2,5,5,5,5,1793684217,0),(3,5,5,5,5,1793684218,0),(4,5,5,5,5,1793684219,0),(5,5,5,5,5,1793684220,0),(6,5,5,5,5,1793684221,0),(7,5,5,5,5,1793750309,0),(8,5,5,5,5,1793750309,0),(9,5,5,5,5,1793757242,0);
/*!40000 ALTER TABLE `kg_course_rating` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_related`
--

DROP TABLE IF EXISTS `kg_course_related`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_related` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `related_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '相关编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_related`
--

LOCK TABLES `kg_course_related` WRITE;
/*!40000 ALTER TABLE `kg_course_related` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_course_related` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_tag`
--

DROP TABLE IF EXISTS `kg_course_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_tag` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `tag_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_tag`
--

LOCK TABLES `kg_course_tag` WRITE;
/*!40000 ALTER TABLE `kg_course_tag` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_course_tag` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_topic`
--

DROP TABLE IF EXISTS `kg_course_topic`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_topic` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `topic_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `topic_id` (`topic_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_topic`
--

LOCK TABLES `kg_course_topic` WRITE;
/*!40000 ALTER TABLE `kg_course_topic` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_course_topic` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_course_user`
--

DROP TABLE IF EXISTS `kg_course_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_course_user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `plan_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '计划编号',
  `source_type` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '来源类型',
  `duration` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习时长',
  `progress` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习进度',
  `reviewed` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评价标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `active_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '活跃时间',
  `expiry_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '过期时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `status` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习状态 0 未开始 1 学习中 2 已完成',
  `completed_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '已完成课时数',
  `total_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '已发布课时总数',
  `first_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '首次学习时间',
  `complete_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '完成时间',
  `complete_version` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '完成时的课程版本',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_course_user`
--

LOCK TABLES `kg_course_user` WRITE;
/*!40000 ALTER TABLE `kg_course_user` DISABLE KEYS */;
INSERT INTO `kg_course_user` VALUES (1,1,20000,20261103,1,0,0,0,0,0,0,1793691120,0,0,0,0,0,0,0),(2,1,10000,20261103,1,1508,100,0,0,1793705310,0,1793708911,0,2,4,4,1793608110,1793701710,1),(3,2,10000,20261103,1,1814,100,0,0,1793709366,0,1793708911,1793709367,2,4,4,1793608110,1793709366,1),(4,3,10000,20261103,1,926,50,0,0,1793705310,0,1793708911,0,1,2,4,1793608110,0,0),(5,4,10000,20261103,1,887,25,0,0,1793705310,0,1793708911,0,1,1,4,1793608110,0,0),(6,7,10000,20261104,1,0,0,0,0,0,0,1793750377,0,0,0,0,0,0,0),(7,6,10000,20261104,7,0,0,0,0,0,0,1793753815,0,0,0,0,0,0,0),(8,5,10000,20261104,7,0,0,0,0,0,0,1793753900,0,0,0,0,0,0,0),(9,8,10000,20261104,1,0,0,0,0,0,0,1793753962,0,0,0,0,0,0,0),(10,9,10000,20261104,1,0,0,0,0,0,0,1793757443,0,0,0,0,0,0,0);
/*!40000 ALTER TABLE `kg_course_user` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_growth_outbox`
--

DROP TABLE IF EXISTS `kg_growth_outbox`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_growth_outbox` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `event_id` varchar(64) NOT NULL DEFAULT '' COMMENT '事件标识，对外幂等键',
  `event_type` varchar(64) NOT NULL DEFAULT '' COMMENT '事件类型',
  `event_version` varchar(10) NOT NULL DEFAULT '1' COMMENT '契约版本',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '事件主体用户',
  `aggregate_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '聚合根，课程或课时编号',
  `payload` text COMMENT '事件载荷 JSON',
  `status` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '0 待投递 1 已投递 2 投递失败',
  `retry_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '已重试次数',
  `last_error` varchar(500) NOT NULL DEFAULT '' COMMENT '最近失败原因',
  `occurred_at` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '事件发生时间',
  `sent_at` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '投递成功时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '记录创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_event_id` (`event_id`),
  KEY `idx_outbox_status` (`status`,`occurred_at`),
  KEY `idx_event_fact` (`event_type`,`user_id`,`aggregate_id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COMMENT='成长档案同步发件箱';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_growth_outbox`
--

LOCK TABLES `kg_growth_outbox` WRITE;
/*!40000 ALTER TABLE `kg_growth_outbox` DISABLE KEYS */;
INSERT INTO `kg_growth_outbox` VALUES (1,'87F225E687296ae9d3703b127','lesson.completed','1.0',10000,2,'{\"eventId\":\"87F225E687296ae9d3703b127\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"eb8fdefdd54f\",\"data\":{\"lessonId\":2,\"lessonTitle\":\"页面骨架与语义化标签\",\"courseId\":1,\"courseTitle\":\"前端开发实战：从页面到交互\",\"watchedSec\":324,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T20:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(2,'E023A5AB94646ae9d3704722c','lesson.completed','1.0',10000,3,'{\"eventId\":\"E023A5AB94646ae9d3704722c\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"a6d9b0156593\",\"data\":{\"lessonId\":3,\"lessonTitle\":\"Flex 与 Grid 布局\",\"courseId\":1,\"courseTitle\":\"前端开发实战：从页面到交互\",\"watchedSec\":359,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T21:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(3,'468A8BFC84536ae9d37053e5b','lesson.completed','1.0',10000,5,'{\"eventId\":\"468A8BFC84536ae9d37053e5b\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"f7abbcaa9d0b\",\"data\":{\"lessonId\":5,\"lessonTitle\":\"DOM 事件与表单校验\",\"courseId\":1,\"courseTitle\":\"前端开发实战：从页面到交互\",\"watchedSec\":395,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T22:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(4,'D076CCF282316ae9d370618e7','lesson.completed','1.0',10000,6,'{\"eventId\":\"D076CCF282316ae9d370618e7\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"541a524f0fc4\",\"data\":{\"lessonId\":6,\"lessonTitle\":\"模块化与构建工具\",\"courseId\":1,\"courseTitle\":\"前端开发实战：从页面到交互\",\"watchedSec\":430,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T23:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(5,'4271F12397686ae9d37074c22','course.completed','1.0',10000,1,'{\"eventId\":\"4271F12397686ae9d37074c22\",\"eventType\":\"course.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"e5c052c3f81b\",\"data\":{\"courseId\":1,\"courseTitle\":\"前端开发实战：从页面到交互\",\"categoryId\":1,\"categoryName\":\"前端开发\",\"completedLessons\":4,\"totalLessons\":4,\"progressPercent\":100.0,\"accumulatedSec\":1508,\"completedCourseVersion\":1,\"completedAt\":\"2026-11-03T18:28:30+08:00\",\"firstLearnedAt\":\"2026-11-02T16:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(6,'A66928F818486ae9d37087b0f','lesson.completed','1.0',10000,8,'{\"eventId\":\"A66928F818486ae9d37087b0f\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"c85c22387e2f\",\"data\":{\"lessonId\":8,\"lessonTitle\":\"列表与元组\",\"courseId\":2,\"courseTitle\":\"Python 算法入门\",\"watchedSec\":466,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T20:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(7,'63BFEE9234466ae9d3709515b','lesson.completed','1.0',10000,9,'{\"eventId\":\"63BFEE9234466ae9d3709515b\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"86a5a5fbee2d\",\"data\":{\"lessonId\":9,\"lessonTitle\":\"字典与集合\",\"courseId\":2,\"courseTitle\":\"Python 算法入门\",\"watchedSec\":501,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T21:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(8,'4B9FABB121616ae9d370a29ec','lesson.completed','1.0',10000,11,'{\"eventId\":\"4B9FABB121616ae9d370a29ec\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"a07e66d50c7e\",\"data\":{\"lessonId\":11,\"lessonTitle\":\"排序算法对比\",\"courseId\":2,\"courseTitle\":\"Python 算法入门\",\"watchedSec\":537,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T22:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(9,'D29C27D435776ae9d370bcbd5','lesson.completed','1.0',10000,14,'{\"eventId\":\"D29C27D435776ae9d370bcbd5\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"b63d2641abcc\",\"data\":{\"lessonId\":14,\"lessonTitle\":\"数据集组织规范\",\"courseId\":3,\"courseTitle\":\"YOLO 目标检测实战\",\"watchedSec\":320,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T20:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(10,'2CB9F94510266ae9d370ce0a7','lesson.completed','1.0',10000,15,'{\"eventId\":\"2CB9F94510266ae9d370ce0a7\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"ba713d1fb7ad\",\"data\":{\"lessonId\":15,\"lessonTitle\":\"标注工具与质量控制\",\"courseId\":3,\"courseTitle\":\"YOLO 目标检测实战\",\"watchedSec\":355,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T21:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(11,'52236A5797356ae9d370eeba1','lesson.completed','1.0',10000,20,'{\"eventId\":\"52236A5797356ae9d370eeba1\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:32+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"74d342aa7d85\",\"data\":{\"lessonId\":20,\"lessonTitle\":\"Dockerfile 编写要点\",\"courseId\":4,\"courseTitle\":\"Docker 容器化部署\",\"watchedSec\":462,\"coveragePercent\":100,\"lastPositionSec\":0,\"completedAt\":\"2026-11-02T20:28:30+08:00\"}}',1,0,'',1793708912,1793708913,1793708912),(12,'F027DE5871076ae9d371104b4','note.created','1.0',10000,1,'{\"eventId\":\"F027DE5871076ae9d371104b4\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"d2b9dda0ba8e\",\"data\":{\"noteId\":1,\"courseId\":1,\"chapterId\":0,\"anchorSec\":0,\"contentLength\":45,\"updatedAt\":\"2026-11-03T06:28:30+08:00\",\"content\":\"课程整体脉络：先讲骨架与语义化，再讲布局，最后落到工程化。复习时按这个顺序过一遍效率最高。\"}}',1,0,'',1793708913,1793708913,1793708913),(13,'82FE6DC827736ae9d3711a3f9','note.created','1.0',10000,2,'{\"eventId\":\"82FE6DC827736ae9d3711a3f9\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"ad44dacdea15\",\"data\":{\"noteId\":2,\"courseId\":1,\"chapterId\":2,\"anchorSec\":96,\"contentLength\":91,\"updatedAt\":\"2026-11-03T08:28:30+08:00\",\"content\":\"Flex 与 Grid 的选择：一维排列用 Flex，二维网格用 Grid。Grid 的 <code>grid-template-areas</code> 在页面级布局里可读性更好。\"}}',1,0,'',1793708913,1793708913,1793708913),(14,'8431183615956ae9d3712365e','note.created','1.0',10000,3,'{\"eventId\":\"8431183615956ae9d3712365e\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"0071d7150cb0\",\"data\":{\"noteId\":3,\"courseId\":1,\"chapterId\":5,\"anchorSec\":214,\"contentLength\":54,\"updatedAt\":\"2026-11-03T10:28:30+08:00\",\"content\":\"表单校验先做原生约束（required、type、pattern），再用 JS 补交互提示，能少写很多逻辑。\"}}',1,0,'',1793708913,1793708913,1793708913),(15,'381E782424176ae9d3712cee1','note.created','1.0',10000,4,'{\"eventId\":\"381E782424176ae9d3712cee1\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"44c30a5ea6e2\",\"data\":{\"noteId\":4,\"courseId\":2,\"chapterId\":8,\"anchorSec\":128,\"contentLength\":36,\"updatedAt\":\"2026-11-03T12:28:30+08:00\",\"content\":\"列表是可变序列，元组不可变。元组适合当\\\"轻量记录\\\"用，比如坐标、配置项。\"}}',1,0,'',1793708913,1793708913,1793708913),(16,'9977F84061836ae9d371365fb','note.created','1.0',10000,5,'{\"eventId\":\"9977F84061836ae9d371365fb\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"cf42018c983b\",\"data\":{\"noteId\":5,\"courseId\":2,\"chapterId\":9,\"anchorSec\":305,\"contentLength\":102,\"updatedAt\":\"2026-11-03T14:28:30+08:00\",\"content\":\"字典取值的三种写法：<code>d[k]</code> 会抛 KeyError，<code>d.get(k)</code> 返回 None，<code>defaultdict</code> 适合聚合计数。\"}}',1,0,'',1793708913,1793708913,1793708913),(17,'A698ECD874186ae9d3713fdd7','note.created','1.0',10000,6,'{\"eventId\":\"A698ECD874186ae9d3713fdd7\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"3cac0d86e7ee\",\"data\":{\"noteId\":6,\"courseId\":3,\"chapterId\":0,\"anchorSec\":0,\"contentLength\":44,\"updatedAt\":\"2026-11-03T16:28:30+08:00\",\"content\":\"图像预处理的顺序：读入 → 尺寸统一 → 归一化 → 增强。顺序错了会导致增强参数失真。\"}}',1,0,'',1793708913,1793708913,1793708913),(18,'ACC77FCC96606ae9d37149faa','note.created','1.0',10000,7,'{\"eventId\":\"ACC77FCC96606ae9d37149faa\",\"eventType\":\"note.created\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:28:33+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"3ee9c875d398\",\"data\":{\"noteId\":7,\"courseId\":4,\"chapterId\":0,\"anchorSec\":0,\"contentLength\":36,\"updatedAt\":\"2026-11-03T18:28:30+08:00\",\"content\":\"容器化的核心是把\\\"运行环境\\\"也当成代码管理，镜像分层缓存能显著加快构建。\"}}',1,0,'',1793708913,1793708913,1793708913),(22,'96423E4665806ae9d537108a7','lesson.completed','1.0',10000,12,'{\"eventId\":\"96423E4665806ae9d537108a7\",\"eventType\":\"lesson.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:36:07+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"5a0874ca5a7f\",\"data\":{\"lessonId\":12,\"lessonTitle\":\"二分查找与复杂度\",\"courseId\":2,\"courseTitle\":\"Python 算法入门\",\"watchedSec\":310,\"coveragePercent\":52,\"lastPositionSec\":30,\"completedAt\":\"2026-11-03T20:36:06+08:00\"}}',1,0,'',1793709367,1793709367,1793709367),(23,'E9FCD20F81036ae9d5371b259','course.completed','1.0',10000,2,'{\"eventId\":\"E9FCD20F81036ae9d5371b259\",\"eventType\":\"course.completed\",\"eventVersion\":\"1.0\",\"occurredAt\":\"2026-11-03T20:36:07+08:00\",\"sourcePlatform\":\"selfstudy\",\"producer\":\"selfstudy-progress-service\",\"userId\":\"10000\",\"traceId\":\"609d8962b09c\",\"data\":{\"courseId\":2,\"courseTitle\":\"Python 算法入门\",\"categoryId\":2,\"categoryName\":\"Python 与算法\",\"completedLessons\":4,\"totalLessons\":4,\"progressPercent\":100.0,\"accumulatedSec\":1814,\"completedCourseVersion\":1,\"completedAt\":\"2026-11-03T20:36:06+08:00\",\"firstLearnedAt\":\"2026-11-02T16:28:30+08:00\"}}',1,0,'',1793709367,1793709367,1793709367);
/*!40000 ALTER TABLE `kg_growth_outbox` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_help`
--

DROP TABLE IF EXISTS `kg_help`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_help` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '分类编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `keywords` varchar(100) NOT NULL DEFAULT '' COMMENT '关键字',
  `content` text NOT NULL COMMENT '内容',
  `priority` int(11) unsigned NOT NULL DEFAULT '10' COMMENT '优先级',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `view_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '浏览数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_help`
--

LOCK TABLES `kg_help` WRITE;
/*!40000 ALTER TABLE `kg_help` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_help` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_learning`
--

DROP TABLE IF EXISTS `kg_learning`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_learning` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `request_id` varchar(64) NOT NULL DEFAULT '' COMMENT '请求编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课时编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `plan_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '计划编号',
  `duration` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '学习时长',
  `position` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '播放位置',
  `client_type` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `active_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '活跃时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `chapter_user` (`chapter_id`,`user_id`),
  KEY `request_id` (`request_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_learning`
--

LOCK TABLES `kg_learning` WRITE;
/*!40000 ALTER TABLE `kg_learning` DISABLE KEYS */;
INSERT INTO `kg_learning` VALUES (1,'test-heartbeat-001',2,12,10000,20261103,60,30,1,'127.0.0.1',1793709366,1793709366,0);
/*!40000 ALTER TABLE `kg_learning` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_learning_note`
--

DROP TABLE IF EXISTS `kg_learning_note`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_learning_note` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课时编号，0 表示仅关联课程',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `content` text NOT NULL COMMENT '笔记正文，纯文本加基础格式',
  `anchor` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时的播放或阅读位置（秒）',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_note_user_course` (`user_id`,`course_id`),
  KEY `idx_note_chapter` (`chapter_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COMMENT='学习笔记';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_learning_note`
--

LOCK TABLES `kg_learning_note` WRITE;
/*!40000 ALTER TABLE `kg_learning_note` DISABLE KEYS */;
INSERT INTO `kg_learning_note` VALUES (1,1,0,10000,'课程整体脉络：先讲骨架与语义化，再讲布局，最后落到工程化。复习时按这个顺序过一遍效率最高。',0,0,1793708911,1793658510),(2,1,2,10000,'Flex 与 Grid 的选择：一维排列用 Flex，二维网格用 Grid。Grid 的 <code>grid-template-areas</code> 在页面级布局里可读性更好。',96,0,1793708911,1793665710),(3,1,5,10000,'表单校验先做原生约束（required、type、pattern），再用 JS 补交互提示，能少写很多逻辑。',214,0,1793708911,1793672910),(4,2,8,10000,'列表是可变序列，元组不可变。元组适合当\"轻量记录\"用，比如坐标、配置项。',128,0,1793708911,1793680110),(5,2,9,10000,'字典取值的三种写法：<code>d[k]</code> 会抛 KeyError，<code>d.get(k)</code> 返回 None，<code>defaultdict</code> 适合聚合计数。',305,0,1793708911,1793687310),(6,3,0,10000,'图像预处理的顺序：读入 → 尺寸统一 → 归一化 → 增强。顺序错了会导致增强参数失真。',0,0,1793708911,1793694510),(7,4,0,10000,'容器化的核心是把\"运行环境\"也当成代码管理，镜像分层缓存能显著加快构建。',0,0,1793708911,1793701710);
/*!40000 ALTER TABLE `kg_learning_note` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_migration`
--

DROP TABLE IF EXISTS `kg_migration`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_migration` (
  `version` bigint(20) NOT NULL,
  `migration_name` varchar(100) DEFAULT NULL,
  `start_time` timestamp NULL DEFAULT NULL,
  `end_time` timestamp NULL DEFAULT NULL,
  `breakpoint` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_migration`
--

LOCK TABLES `kg_migration` WRITE;
/*!40000 ALTER TABLE `kg_migration` DISABLE KEYS */;
INSERT INTO `kg_migration` VALUES (20210324064239,'V20210324064239','2026-11-03 05:31:46','2026-11-03 05:31:48',0),(20210403184518,'V20210403184518','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210720153027,'V20210720153027','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210802021814,'V20210802021814','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210809153030,'V20210809153030','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210820064755,'V20210820064755','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210825111618,'V20210825111618','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210903040558,'V20210903040558','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210916072842,'V20210916072842','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20210917093354,'V20210917093354','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20211017085325,'V20211017085325','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20211019093522,'V20211019093522','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20211231013226,'V20211231013226','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20220117122902,'V20220117122902','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20220607014823,'V20220607014823','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20220801025747,'V20220801025747','2026-11-03 05:31:48','2026-11-03 05:31:48',0),(20220915084746,'V20220915084746','2026-11-03 05:31:48','2026-11-03 05:31:49',0),(20221021035953,'V20221021035953','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20230522141831,'V20230522141831','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20230611193031,'V20230611193031','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20230625182830,'V20230625182830','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20230816234130,'V20230816234130','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20230910174508,'V20230910174508','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20231108085025,'V20231108085025','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20240111185333,'V20240111185333','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20240608110418,'V20240608110418','2026-11-03 05:31:49','2026-11-03 05:31:49',0),(20261103201500,'V20261103201500','2026-11-03 12:20:40','2026-11-03 12:20:41',0);
/*!40000 ALTER TABLE `kg_migration` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_migration_task`
--

DROP TABLE IF EXISTS `kg_migration_task`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_migration_task` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `version` varchar(100) NOT NULL DEFAULT '' COMMENT '版本',
  `start_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `version` (`version`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_migration_task`
--

LOCK TABLES `kg_migration_task` WRITE;
/*!40000 ALTER TABLE `kg_migration_task` DISABLE KEYS */;
INSERT INTO `kg_migration_task` VALUES (1,'V20240608145810',1793749877,1793749877),(2,'V20241110191316',1793749877,1793749877),(3,'V20250110191618',1793749877,1793749877),(4,'V20261104080000',1793749906,1793749906);
/*!40000 ALTER TABLE `kg_migration_task` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_nav`
--

DROP TABLE IF EXISTS `kg_nav`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_nav` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `parent_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '父级编号',
  `level` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '层级',
  `name` varchar(30) NOT NULL DEFAULT '' COMMENT '名称',
  `path` varchar(30) NOT NULL DEFAULT '' COMMENT '路径',
  `target` varchar(30) NOT NULL DEFAULT '_blank' COMMENT '打开方式',
  `url` varchar(100) NOT NULL DEFAULT '' COMMENT '链接地址',
  `position` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '位置',
  `priority` int(11) unsigned NOT NULL DEFAULT '30' COMMENT '优先级',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `child_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '子类数量',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_nav`
--

LOCK TABLES `kg_nav` WRITE;
/*!40000 ALTER TABLE `kg_nav` DISABLE KEYS */;
INSERT INTO `kg_nav` VALUES (1,0,1,'首页',',1,','_self','/',1,1,1,0,0,1793683908,0),(2,0,1,'课程',',2,','_self','/course/list',1,2,1,0,0,1793683908,0),(3,0,1,'专栏',',3,','_self','/article/list',1,3,1,0,0,1793683908,0),(4,0,1,'问答',',4,','_self','/question/list',1,4,1,0,0,1793683908,0),(5,0,1,'师资',',5,','_self','/teacher/list',1,5,1,0,0,1793683908,0),(8,0,1,'关于我们',',8,','_blank','#',2,1,1,0,0,1793683908,0),(9,0,1,'联系我们',',9,','_blank','#',2,2,1,0,0,1793683908,0),(10,0,1,'人才招聘',',10,','_blank','#',2,3,1,0,0,1793683908,0),(11,0,1,'帮助中心',',11,','_blank','/help',2,4,1,0,0,1793683908,0),(12,0,1,'友情链接',',12,','_blank','#',2,5,1,0,0,1793683908,0);
/*!40000 ALTER TABLE `kg_nav` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_notification`
--

DROP TABLE IF EXISTS `kg_notification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_notification` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `sender_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发送方编号',
  `receiver_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '接收方编号',
  `event_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '事件编号',
  `event_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '事件类型',
  `event_info` varchar(1500) NOT NULL DEFAULT '' COMMENT '事件内容',
  `viewed` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '已读标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `receiver_id` (`receiver_id`),
  KEY `sender_id` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_notification`
--

LOCK TABLES `kg_notification` WRITE;
/*!40000 ALTER TABLE `kg_notification` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_notification` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_online`
--

DROP TABLE IF EXISTS `kg_online`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_online` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `client_type` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `active_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '活跃时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `active_time` (`active_time`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_online`
--

LOCK TABLES `kg_online` WRITE;
/*!40000 ALTER TABLE `kg_online` DISABLE KEYS */;
INSERT INTO `kg_online` VALUES (1,10000,1,'127.0.0.1',1793715365,1793712442,1793715365),(2,10000,1,'127.0.0.1',1793777999,1793753782,1793777999);
/*!40000 ALTER TABLE `kg_online` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_order`
--

DROP TABLE IF EXISTS `kg_order`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_order` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `sn` varchar(32) NOT NULL DEFAULT '' COMMENT '订单编号',
  `subject` varchar(100) NOT NULL DEFAULT '' COMMENT '订单标题',
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '订单金额',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `item_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目编号',
  `item_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目类型',
  `item_info` varchar(3000) NOT NULL DEFAULT '' COMMENT '条目内容',
  `promotion_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '促销编号',
  `promotion_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '促销类型',
  `promotion_info` varchar(1000) NOT NULL DEFAULT '' COMMENT '促销信息',
  `client_type` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `status` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '状态标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `create_time` (`create_time`),
  KEY `item` (`item_id`,`item_type`),
  KEY `owner_id` (`owner_id`),
  KEY `sn` (`sn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_order`
--

LOCK TABLES `kg_order` WRITE;
/*!40000 ALTER TABLE `kg_order` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_order` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_order_status`
--

DROP TABLE IF EXISTS `kg_order_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_order_status` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `order_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '订单编号',
  `status` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '订单状态',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_order_status`
--

LOCK TABLES `kg_order_status` WRITE;
/*!40000 ALTER TABLE `kg_order_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_order_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_package`
--

DROP TABLE IF EXISTS `kg_package`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_package` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL COMMENT '封面',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `market_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '市场价格',
  `vip_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '会员价格',
  `course_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程数量',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_package`
--

LOCK TABLES `kg_package` WRITE;
/*!40000 ALTER TABLE `kg_package` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_package` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_page`
--

DROP TABLE IF EXISTS `kg_page`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_page` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `alias` varchar(50) NOT NULL DEFAULT '' COMMENT '别名',
  `keywords` varchar(100) NOT NULL DEFAULT '' COMMENT '关键字',
  `content` text NOT NULL COMMENT '内容',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `view_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '浏览数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_page`
--

LOCK TABLES `kg_page` WRITE;
/*!40000 ALTER TABLE `kg_page` DISABLE KEYS */;
INSERT INTO `kg_page` VALUES (1,'用户协议','terms','','',1,0,0,1793683909,0),(2,'隐私政策','privacy','','',1,0,0,1793683909,0);
/*!40000 ALTER TABLE `kg_page` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_point_gift`
--

DROP TABLE IF EXISTS `kg_point_gift`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_point_gift` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '名称',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `details` text NOT NULL COMMENT '详情',
  `attrs` varchar(1000) NOT NULL DEFAULT '' COMMENT '扩展属性',
  `type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '类型',
  `stock` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '库存',
  `point` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '所需积分',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `redeem_limit` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '兑换限额',
  `redeem_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '兑换数量',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_point_gift`
--

LOCK TABLES `kg_point_gift` WRITE;
/*!40000 ALTER TABLE `kg_point_gift` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_point_gift` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_point_gift_redeem`
--

DROP TABLE IF EXISTS `kg_point_gift_redeem`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_point_gift_redeem` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `user_name` varchar(30) NOT NULL DEFAULT '' COMMENT '用户名称',
  `gift_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '礼品编号',
  `gift_name` varchar(100) NOT NULL DEFAULT '' COMMENT '礼品名称',
  `gift_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '礼品类型',
  `gift_point` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '礼品积分',
  `contact_name` varchar(30) NOT NULL DEFAULT '' COMMENT '联系人',
  `contact_phone` varchar(30) NOT NULL DEFAULT '' COMMENT '联系电话',
  `contact_address` varchar(100) NOT NULL DEFAULT '' COMMENT '联系地址',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `status` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '状态标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `gift_id` (`gift_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_point_gift_redeem`
--

LOCK TABLES `kg_point_gift_redeem` WRITE;
/*!40000 ALTER TABLE `kg_point_gift_redeem` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_point_gift_redeem` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_point_history`
--

DROP TABLE IF EXISTS `kg_point_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_point_history` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL COMMENT '用户编号',
  `user_name` varchar(30) NOT NULL DEFAULT '' COMMENT '用户名称',
  `event_id` int(11) unsigned NOT NULL COMMENT '事件编号',
  `event_type` int(11) unsigned NOT NULL COMMENT '事件类型',
  `event_info` varchar(1000) NOT NULL DEFAULT '0' COMMENT '事件内容',
  `event_point` int(11) NOT NULL DEFAULT '0' COMMENT '事件积分',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `event` (`event_id`,`event_type`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_point_history`
--

LOCK TABLES `kg_point_history` WRITE;
/*!40000 ALTER TABLE `kg_point_history` DISABLE KEYS */;
INSERT INTO `kg_point_history` VALUES (1,10000,'酷瓜云课堂',9,6,'{\"course\":{\"id\":2,\"title\":\"Python 算法入门\"},\"chapter\":{\"id\":12,\"title\":\"二分查找与复杂度\"}}',10,1793709367,0),(2,10000,'酷瓜云课堂',10000,5,'[]',10,1793712442,0),(3,10000,'酷瓜云课堂',10000,5,'[]',10,1793753782,0);
/*!40000 ALTER TABLE `kg_point_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_question`
--

DROP TABLE IF EXISTS `kg_question`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_question` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '分类编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `last_replier_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '最后回应用户',
  `last_answer_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '最后回答编号',
  `accept_answer_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '采纳回答编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL COMMENT '封面',
  `tags` varchar(255) NOT NULL DEFAULT '[]' COMMENT '标签',
  `keywords` varchar(100) NOT NULL DEFAULT '' COMMENT '关键字',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '概要',
  `content` text NOT NULL COMMENT '内容',
  `score` float NOT NULL DEFAULT '0' COMMENT '综合得分',
  `bounty` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '悬赏积分',
  `anonymous` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '匿名标识',
  `solved` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '解决标识',
  `closed` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '关闭标识',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `featured` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '推荐标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `view_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '浏览数',
  `answer_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '答案数',
  `comment_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评论数',
  `favorite_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '收藏数',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `last_reply_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '回应时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  KEY `last_reply_time` (`last_reply_time`),
  KEY `owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_question`
--

LOCK TABLES `kg_question` WRITE;
/*!40000 ALTER TABLE `kg_question` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_question` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_question_favorite`
--

DROP TABLE IF EXISTS `kg_question_favorite`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_question_favorite` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `question_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '问题编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `question_id` (`question_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_question_favorite`
--

LOCK TABLES `kg_question_favorite` WRITE;
/*!40000 ALTER TABLE `kg_question_favorite` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_question_favorite` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_question_like`
--

DROP TABLE IF EXISTS `kg_question_like`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_question_like` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `question_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '问题编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `question_user` (`question_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_question_like`
--

LOCK TABLES `kg_question_like` WRITE;
/*!40000 ALTER TABLE `kg_question_like` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_question_like` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_question_tag`
--

DROP TABLE IF EXISTS `kg_question_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_question_tag` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `question_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '问题编号',
  `tag_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `question_id` (`question_id`),
  KEY `tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_question_tag`
--

LOCK TABLES `kg_question_tag` WRITE;
/*!40000 ALTER TABLE `kg_question_tag` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_question_tag` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_refund`
--

DROP TABLE IF EXISTS `kg_refund`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_refund` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `order_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '订单编号',
  `trade_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '交易编号',
  `sn` varchar(32) NOT NULL DEFAULT '' COMMENT '退款序号',
  `subject` varchar(100) NOT NULL DEFAULT '' COMMENT '退款主题',
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '退款金额',
  `status` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '状态类型',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `apply_note` varchar(255) NOT NULL DEFAULT '' COMMENT '申请备注',
  `review_note` varchar(255) NOT NULL DEFAULT '' COMMENT '审核备注',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `order_id` (`order_id`),
  KEY `owner_id` (`owner_id`),
  KEY `sn` (`sn`),
  KEY `trade_id` (`trade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_refund`
--

LOCK TABLES `kg_refund` WRITE;
/*!40000 ALTER TABLE `kg_refund` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_refund` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_refund_status`
--

DROP TABLE IF EXISTS `kg_refund_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_refund_status` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `refund_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '订单编号',
  `status` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '订单状态',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `refund_id` (`refund_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_refund_status`
--

LOCK TABLES `kg_refund_status` WRITE;
/*!40000 ALTER TABLE `kg_refund_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_refund_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_report`
--

DROP TABLE IF EXISTS `kg_report`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_report` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `reason` varchar(1000) NOT NULL DEFAULT '' COMMENT '理由',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `item_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目编号',
  `item_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目类型',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `reviewed` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '处理标识',
  `accepted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '采纳标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `item` (`item_id`,`item_type`),
  KEY `owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_report`
--

LOCK TABLES `kg_report` WRITE;
/*!40000 ALTER TABLE `kg_report` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_report` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_resource`
--

DROP TABLE IF EXISTS `kg_resource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_resource` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `upload_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '上传编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_resource`
--

LOCK TABLES `kg_resource` WRITE;
/*!40000 ALTER TABLE `kg_resource` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_resource` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_review`
--

DROP TABLE IF EXISTS `kg_review`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_review` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `content` varchar(1000) NOT NULL DEFAULT '' COMMENT '内容',
  `reply` varchar(1000) NOT NULL DEFAULT '' COMMENT '回复',
  `rating` float NOT NULL DEFAULT '5' COMMENT '综合评分',
  `rating1` float NOT NULL DEFAULT '5' COMMENT '维度1评分',
  `rating2` float NOT NULL DEFAULT '5' COMMENT '维度2评分',
  `rating3` float NOT NULL DEFAULT '5' COMMENT '维度3评分',
  `anonymous` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '匿名标识',
  `published` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `like_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '点赞数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_review`
--

LOCK TABLES `kg_review` WRITE;
/*!40000 ALTER TABLE `kg_review` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_review` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_review_like`
--

DROP TABLE IF EXISTS `kg_review_like`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_review_like` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `review_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评价编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `review_user` (`review_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_review_like`
--

LOCK TABLES `kg_review_like` WRITE;
/*!40000 ALTER TABLE `kg_review_like` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_review_like` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_role`
--

DROP TABLE IF EXISTS `kg_role`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_role` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `type` int(11) unsigned NOT NULL DEFAULT '2' COMMENT '类型',
  `name` varchar(30) NOT NULL DEFAULT '' COMMENT '名称',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `routes` text NOT NULL COMMENT '权限路由',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `user_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '成员数量',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_role`
--

LOCK TABLES `kg_role` WRITE;
/*!40000 ALTER TABLE `kg_role` DISABLE KEYS */;
INSERT INTO `kg_role` VALUES (1,1,'管理员','管理员','[]',0,1,1793683908,0),(2,1,'运营','运营人员','[]',0,0,1793683908,0),(3,1,'编辑','编辑人员','[]',0,0,1793683908,0),(4,1,'财务','财务人员','[]',0,0,1793683908,0);
/*!40000 ALTER TABLE `kg_role` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_setting`
--

DROP TABLE IF EXISTS `kg_setting`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_setting` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `section` varchar(50) NOT NULL DEFAULT '' COMMENT '配置组',
  `item_key` varchar(50) NOT NULL DEFAULT '' COMMENT '配置项',
  `item_value` text NOT NULL COMMENT '配置值',
  PRIMARY KEY (`id`),
  UNIQUE KEY `section_key` (`section`,`item_key`)
) ENGINE=InnoDB AUTO_INCREMENT=131 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_setting`
--

LOCK TABLES `kg_setting` WRITE;
/*!40000 ALTER TABLE `kg_setting` DISABLE KEYS */;
INSERT INTO `kg_setting` VALUES (1,'live.push','domain',''),(2,'live.push','auth_enabled','1'),(3,'live.push','auth_key',''),(4,'live.push','auth_delta','18000'),(5,'live.pull','protocol','http'),(6,'live.pull','domain',''),(7,'live.pull','trans_enabled','0'),(8,'live.pull','auth_enabled','1'),(9,'live.pull','auth_key',''),(10,'live.pull','auth_delta','18000'),(11,'live.notify','auth_key',''),(12,'live.notify','stream_begin_url',''),(13,'live.notify','stream_end_url',''),(14,'live.notify','record_url',''),(15,'live.notify','snapshot_url',''),(16,'live.notify','porn_url',''),(17,'mail','smtp_host',''),(18,'mail','smtp_port','465'),(19,'mail','smtp_encryption','ssl'),(20,'mail','smtp_auth_enabled','1'),(21,'mail','smtp_username',''),(22,'mail','smtp_password',''),(23,'mail','smtp_from_email',''),(24,'mail','smtp_from_name',''),(25,'pay.alipay','enabled','1'),(26,'pay.alipay','app_id',''),(27,'pay.alipay','public_key',''),(28,'pay.alipay','private_key',''),(29,'pay.alipay','return_url',''),(30,'pay.alipay','notify_url',''),(31,'pay.alipay','service_rate','5'),(32,'pay.wxpay','enabled','1'),(33,'pay.wxpay','mp_app_id',''),(34,'pay.wxpay','mini_app_id',''),(35,'pay.wxpay','app_id',''),(36,'pay.wxpay','mch_id',''),(37,'pay.wxpay','key',''),(38,'pay.wxpay','notify_url',''),(39,'pay.wxpay','return_url',''),(40,'pay.wxpay','service_rate','5'),(41,'secret','secret_key','xxx'),(42,'secret','secret_id','xxx'),(43,'secret','app_id','xxx'),(44,'site','title','自学平台'),(45,'site','keywords','自学平台,警务人才培养,在线课程,前端开发,Python 算法,计算机视觉,容器部署,数据库,网络安全,警务业务知识'),(46,'site','description','面向警务人才培养的自主学习平台，提供前端开发、Python 算法、计算机视觉、容器部署、数据库、网络安全与警务业务知识等课程。'),(47,'site','logo',''),(48,'site','favicon',''),(49,'site','url',''),(50,'site','status','normal'),(51,'site','closed_tips','站点维护中，请稍后再访问。'),(52,'site','index_tpl_type','simple'),(53,'site','copyright','2026 自学平台'),(54,'site','icp_sn',''),(55,'site','icp_link','http://beian.miit.gov.cn'),(56,'site','police_sn',''),(57,'site','police_link',''),(58,'site','analytics_enabled','0'),(59,'site','analytics_script',''),(60,'sms','app_id',''),(61,'sms','app_key',''),(62,'sms','signature',''),(63,'sms','template','{\"verify\":{\"enabled\":1,\"id\":0},\"order_finish\":{\"enabled\":0,\"id\":0},\"refund_finish\":{\"enabled\":0,\"id\":0},\"live_begin\":{\"enabled\":0,\"id\":0},\"consult_reply\":{\"enabled\":0,\"id\":0},\"goods_deliver\":{\"enabled\":0,\"id\":0}}'),(64,'cos','bucket','course-1255691183'),(65,'cos','region','ap-guangzhou'),(66,'cos','protocol','http'),(67,'cos','domain','127.0.0.1:8000/static'),(68,'vod','storage_type','nearby'),(69,'vod','storage_region',''),(70,'vod','audio_format','mp3'),(71,'vod','video_format','hls'),(72,'vod','wmk_enabled','1'),(73,'vod','wmk_tpl_id',''),(74,'vod','protocol','https'),(75,'vod','domain',''),(76,'vod','key_anti_enabled','1'),(77,'vod','key_anti_key',''),(78,'vod','key_anti_expiry','10800'),(79,'vod','key_anti_ip_limit','3'),(80,'dingtalk.robot','enabled','0'),(81,'dingtalk.robot','app_secret',''),(82,'dingtalk.robot','app_token',''),(83,'dingtalk.robot','ts_mobiles',''),(84,'dingtalk.robot','cs_mobiles',''),(85,'oauth.qq','enabled','0'),(86,'oauth.qq','client_id',''),(87,'oauth.qq','client_secret',''),(88,'oauth.qq','redirect_uri',''),(89,'oauth.weixin','enabled','0'),(90,'oauth.weixin','client_id',''),(91,'oauth.weixin','client_secret',''),(92,'oauth.weixin','redirect_uri',''),(93,'oauth.weibo','enabled','0'),(94,'oauth.weibo','client_id',''),(95,'oauth.weibo','client_secret',''),(96,'oauth.weibo','redirect_uri',''),(97,'oauth.weibo','refuse_uri',''),(98,'wechat.oa','enabled','0'),(99,'wechat.oa','app_id',''),(100,'wechat.oa','app_secret',''),(101,'wechat.oa','app_token',''),(102,'wechat.oa','aes_key',''),(103,'wechat.oa','notify_url',''),(104,'wechat.oa','notice_template','{\"account_login\":{\"enabled\":0,\"id\":0},\"order_finish\":{\"enabled\":0,\"id\":0},\"refund_finish\":{\"enabled\":0,\"id\":0},\"goods_deliver\":{\"enabled\":0,\"id\":0},\"consult_reply\":{\"enabled\":0,\"id\":0},\"live_begin\":{\"enabled\":0,\"id\":0}}'),(105,'wechat.oa','menu','[{\"name\":\"\\u83dc\\u53551\",\"url\":\"\",\"children\":[{\"type\":\"view\",\"name\":\"\\u83dc\\u53551-1\",\"url\":\"https:\\/\\/gitee.com\\/koogua\"}]},{\"name\":\"\\u83dc\\u53552\",\"url\":\"\",\"children\":[{\"type\":\"view\",\"name\":\"\\u83dc\\u53552-1\",\"url\":\"https:\\/\\/gitee.com\\/koogua\"}]},{\"name\":\"\\u83dc\\u53553\",\"url\":\"\",\"children\":[{\"type\":\"view\",\"name\":\"\\u83dc\\u53553-1\",\"url\":\"https:\\/\\/gitee.com\\/koogua\"}]}]'),(106,'point','enabled','1'),(107,'point','consume_rule','{\"enabled\":1,\"rate\":5}'),(108,'point','event_rule','{\"account_register\":{\"enabled\":1,\"point\":100},\"course_review\":{\"enabled\":1,\"point\":50},\"chapter_study\":{\"enabled\":1,\"point\":10},\"site_visit\":{\"enabled\":1,\"point\":10},\"article_post\":{\"enabled\":1,\"point\":20,\"limit\":50},\"question_post\":{\"enabled\":1,\"point\":5,\"limit\":50},\"answer_post\":{\"enabled\":1,\"point\":5,\"limit\":50},\"comment_post\":{\"enabled\":1,\"point\":2,\"limit\":10},\"article_liked\":{\"enabled\":1,\"point\":1,\"limit\":50},\"question_liked\":{\"enabled\":1,\"point\":1,\"limit\":50},\"answer_liked\":{\"enabled\":1,\"point\":1,\"limit\":50}}'),(109,'vod','video_quality','[\"hd\",\"sd\",\"fd\"]'),(110,'vod','audio_quality','[\"sd\"]'),(111,'contact','enabled','0'),(112,'contact','qq',''),(113,'contact','wechat',''),(114,'contact','toutiao',''),(115,'contact','weibo',''),(116,'contact','zhihu',''),(117,'contact','email',''),(118,'contact','phone',''),(119,'contact','address',''),(120,'oauth.local','login_with_phone','1'),(121,'oauth.local','login_with_email','1'),(122,'oauth.local','register_with_phone','1'),(123,'oauth.local','register_with_email','1'),(124,'sms','region','ap-guangzhou'),(125,'site','isp_sn',''),(126,'site','isp_link','https://dxzhgl.miit.gov.cn'),(127,'site','company_sn',''),(128,'site','company_sn_link',''),(129,'dingtalk.robot','webhook_url',''),(130,'contact','douyin','');
/*!40000 ALTER TABLE `kg_setting` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_slide`
--

DROP TABLE IF EXISTS `kg_slide`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_slide` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `content` varchar(255) NOT NULL DEFAULT '' COMMENT '内容',
  `platform` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '平台类型',
  `target` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '目标类型',
  `target_attrs` varchar(1000) NOT NULL DEFAULT '' COMMENT '目标属性',
  `priority` int(11) unsigned NOT NULL DEFAULT '10' COMMENT '优先级',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布状态',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_slide`
--

LOCK TABLES `kg_slide` WRITE;
/*!40000 ALTER TABLE `kg_slide` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_slide` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_tag`
--

DROP TABLE IF EXISTS `kg_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_tag` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '名称',
  `alias` varchar(50) NOT NULL DEFAULT '' COMMENT '别名',
  `icon` varchar(100) NOT NULL DEFAULT '' COMMENT '图标',
  `scopes` varchar(100) NOT NULL DEFAULT 'all' COMMENT '范围',
  `priority` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '优先级',
  `published` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `follow_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '关注数',
  `course_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程数',
  `article_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '文章数',
  `question_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '问题数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_tag`
--

LOCK TABLES `kg_tag` WRITE;
/*!40000 ALTER TABLE `kg_tag` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_tag` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_tag_follow`
--

DROP TABLE IF EXISTS `kg_tag_follow`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_tag_follow` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `tag_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '标签编号',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `tag_id` (`tag_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_tag_follow`
--

LOCK TABLES `kg_tag_follow` WRITE;
/*!40000 ALTER TABLE `kg_tag_follow` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_tag_follow` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_task`
--

DROP TABLE IF EXISTS `kg_task`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_task` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `item_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目编号',
  `item_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目类型',
  `item_info` varchar(3000) NOT NULL DEFAULT '' COMMENT '条目内容',
  `status` int(11) NOT NULL DEFAULT '1' COMMENT '状态',
  `priority` int(11) unsigned NOT NULL DEFAULT '30' COMMENT '优先级',
  `try_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '重试数',
  `max_try_count` int(11) unsigned NOT NULL DEFAULT '3' COMMENT '最大重试数',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_task`
--

LOCK TABLES `kg_task` WRITE;
/*!40000 ALTER TABLE `kg_task` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_task` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_topic`
--

DROP TABLE IF EXISTS `kg_topic`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_topic` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `keywords` varchar(100) NOT NULL DEFAULT '' COMMENT '关键字',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `course_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程数量',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_topic`
--

LOCK TABLES `kg_topic` WRITE;
/*!40000 ALTER TABLE `kg_topic` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_topic` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_trade`
--

DROP TABLE IF EXISTS `kg_trade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_trade` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `owner_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `order_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '订单编号',
  `sn` varchar(32) NOT NULL DEFAULT '' COMMENT '交易序号',
  `subject` varchar(100) NOT NULL DEFAULT '' COMMENT '交易主题',
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '交易金额',
  `channel` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '平台类型',
  `channel_sn` varchar(64) NOT NULL DEFAULT '' COMMENT '平台序号',
  `status` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '状态类型',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `order_id` (`order_id`),
  KEY `owner_id` (`owner_id`),
  KEY `sn` (`sn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_trade`
--

LOCK TABLES `kg_trade` WRITE;
/*!40000 ALTER TABLE `kg_trade` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_trade` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_trade_status`
--

DROP TABLE IF EXISTS `kg_trade_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_trade_status` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `trade_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '订单编号',
  `status` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '订单状态',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `trade_id` (`trade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_trade_status`
--

LOCK TABLES `kg_trade_status` WRITE;
/*!40000 ALTER TABLE `kg_trade_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_trade_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_upload`
--

DROP TABLE IF EXISTS `kg_upload`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_upload` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '条目类型',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '文件名',
  `path` varchar(100) NOT NULL DEFAULT '' COMMENT '路径',
  `mime` varchar(100) NOT NULL DEFAULT '' COMMENT 'mime',
  `md5` varchar(32) NOT NULL DEFAULT '' COMMENT 'md5',
  `size` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '大小',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `md5` (`md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_upload`
--

LOCK TABLES `kg_upload` WRITE;
/*!40000 ALTER TABLE `kg_upload` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_upload` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_user`
--

DROP TABLE IF EXISTS `kg_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_user` (
  `id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '主键编号',
  `name` varchar(30) NOT NULL DEFAULT '' COMMENT '名称',
  `avatar` varchar(100) NOT NULL DEFAULT '' COMMENT '头像',
  `title` varchar(30) NOT NULL DEFAULT '' COMMENT '头衔',
  `about` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `area` varchar(30) NOT NULL DEFAULT '' COMMENT '地区',
  `gender` int(11) unsigned NOT NULL DEFAULT '3' COMMENT '性别',
  `vip` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '会员标识',
  `locked` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '锁定标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `edu_role` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '教学角色',
  `admin_role` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '后台角色',
  `course_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '课程数',
  `article_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '文章数',
  `question_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '提问数',
  `answer_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '回答数',
  `comment_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '评论数',
  `favorite_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '收藏数',
  `notice_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '通知数',
  `report_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '举报数',
  `vip_expiry_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '会员期限',
  `lock_expiry_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '锁定期限',
  `active_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '活跃时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_user`
--

LOCK TABLES `kg_user` WRITE;
/*!40000 ALTER TABLE `kg_user` DISABLE KEYS */;
INSERT INTO `kg_user` VALUES (10000,'自学平台','/img/default/user_avatar.png','官方人员','酷瓜云课堂，开源在线教育解决方案','',3,0,0,0,2,1,9,0,0,0,0,1,0,0,0,0,1793777999,1793683908,1793777999),(20000,'审计测试学员','/img/default/user_avatar.png','','','',3,0,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,1793691085,1793691145);
/*!40000 ALTER TABLE `kg_user` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_user_balance`
--

DROP TABLE IF EXISTS `kg_user_balance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_user_balance` (
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `cash` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '可用现金',
  `point` int(11) NOT NULL DEFAULT '0' COMMENT '可用积分',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_user_balance`
--

LOCK TABLES `kg_user_balance` WRITE;
/*!40000 ALTER TABLE `kg_user_balance` DISABLE KEYS */;
INSERT INTO `kg_user_balance` VALUES (10000,0.00,30,1793683908,1793753782);
/*!40000 ALTER TABLE `kg_user_balance` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_user_contact`
--

DROP TABLE IF EXISTS `kg_user_contact`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_user_contact` (
  `user_id` int(11) unsigned NOT NULL COMMENT '用户编号',
  `name` varchar(30) NOT NULL DEFAULT '' COMMENT '姓名',
  `phone` varchar(30) NOT NULL DEFAULT '' COMMENT '电话',
  `add_province` varchar(30) NOT NULL DEFAULT '' COMMENT '地址(省)',
  `add_city` varchar(30) NOT NULL DEFAULT '' COMMENT '地址(市)',
  `add_county` varchar(30) NOT NULL DEFAULT '' COMMENT '地址(区)',
  `add_other` varchar(50) NOT NULL DEFAULT '' COMMENT '地址(详)',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_user_contact`
--

LOCK TABLES `kg_user_contact` WRITE;
/*!40000 ALTER TABLE `kg_user_contact` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_user_contact` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_user_session`
--

DROP TABLE IF EXISTS `kg_user_session`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_user_session` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `session_id` varchar(64) NOT NULL DEFAULT '' COMMENT '会话编号',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `expire_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '过期时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_user_session`
--

LOCK TABLES `kg_user_session` WRITE;
/*!40000 ALTER TABLE `kg_user_session` DISABLE KEYS */;
INSERT INTO `kg_user_session` VALUES (1,10000,'b146157ceddb39bea4d2604a5b3056a1',1,'127.0.0.1',0,1793770684,1793684284,0),(2,10000,'99135fac8ba455f4d922493fe1127f49',1,'127.0.0.1',0,1793770705,1793684305,0),(3,10000,'ff9c3de0725b30d7325c730962534a76',1,'127.0.0.1',0,1793770937,1793684537,0),(4,10000,'ff9c3de0725b30d7325c730962534a76',1,'127.0.0.1',0,1793770943,1793684543,0),(5,10000,'f6147d756ad75e01466070a08121d3b7',1,'127.0.0.1',0,1793771068,1793684668,0),(6,10000,'70c6e7f36bbcc1cddb164c5dd75dc2e0',1,'127.0.0.1',0,1793771106,1793684706,0),(7,20000,'f584bd138cd9614ca5d33a682deccec3',1,'127.0.0.1',0,1793777515,1793691115,0),(8,10000,'5db5444a75bbaa2a83681b33b746332e',1,'127.0.0.1',0,1793779703,1793693303,0),(9,10000,'4d840570349f02e68d178e279b3fb6b1',1,'127.0.0.1',0,1793779876,1793693476,0),(10,10000,'90df1c9d52acd70fb708ec6a2a2534b4',1,'127.0.0.1',0,1793795393,1793708993,0),(11,10000,'f6d3f321cad5d234aff5b2284937da55',1,'127.0.0.1',0,1793795810,1793709410,0),(12,10000,'51a86e8605506d720ba2c24be51174c9',1,'127.0.0.1',0,1793795833,1793709433,0),(13,10000,'4be1f21ee5220f2b7d72d1d89f9e0e5b',1,'127.0.0.1',0,1793795890,1793709490,0),(14,10000,'c1db97da4113be730b18d94af6cb5d08',1,'127.0.0.1',0,1793795961,1793709561,0),(15,10000,'2c587e13b1fcda053581b2201ff98bdb',1,'127.0.0.1',0,1793796016,1793709616,0),(16,10000,'4554730708a52e8647dbc3a75548772b',1,'127.0.0.1',0,1793796040,1793709640,0),(17,10000,'859b8b7c2d4422b9695004614d257d8f',1,'127.0.0.1',0,1793796068,1793709668,0),(18,10000,'cf47f28aeb41e0884d30d21176b72335',1,'127.0.0.1',0,1793796124,1793709724,0),(19,10000,'81561a8e1dd8df43a43335e1fd5038e7',1,'127.0.0.1',0,1793796139,1793709739,0),(20,10000,'da0ac3354092717a9796290e962554cb',1,'127.0.0.1',0,1793796158,1793709758,0),(21,10000,'81aeafdb14804194be4fae74770fc538',1,'127.0.0.1',0,1793796181,1793709781,0),(22,10000,'0292c3878ca5f11140f10aa101261e3b',1,'127.0.0.1',0,1793796211,1793709811,0),(23,10000,'dc43ece5ea781ea62c3e89827cbc15b3',1,'127.0.0.1',0,1793796231,1793709831,0),(24,10000,'f552f2fd8c1bbc48872c6acd3f69df09',1,'127.0.0.1',0,1793796276,1793709876,0),(25,10000,'01742f7506a982c66abe737149342a1d',1,'127.0.0.1',0,1793796298,1793709898,0),(26,10000,'c89e3ac76c5d8ae7ac1e92bae295a8d8',1,'127.0.0.1',0,1793796403,1793710003,0);
/*!40000 ALTER TABLE `kg_user_session` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_user_token`
--

DROP TABLE IF EXISTS `kg_user_token`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_user_token` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户编号',
  `token` varchar(64) NOT NULL DEFAULT '' COMMENT '身份令牌',
  `client_type` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端类型',
  `client_ip` varchar(64) NOT NULL DEFAULT '' COMMENT '终端IP',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `expire_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '过期时间',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_user_token`
--

LOCK TABLES `kg_user_token` WRITE;
/*!40000 ALTER TABLE `kg_user_token` DISABLE KEYS */;
/*!40000 ALTER TABLE `kg_user_token` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_vip`
--

DROP TABLE IF EXISTS `kg_vip`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_vip` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键编号',
  `title` varchar(30) NOT NULL DEFAULT '' COMMENT '标题',
  `cover` varchar(100) NOT NULL DEFAULT '' COMMENT '封面',
  `expiry` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '有效期',
  `price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '价格',
  `published` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发布标识',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '删除标识',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_vip`
--

LOCK TABLES `kg_vip` WRITE;
/*!40000 ALTER TABLE `kg_vip` DISABLE KEYS */;
INSERT INTO `kg_vip` VALUES (1,'1个月','',1,60.00,1,0,1793683908,0),(2,'3个月','',3,150.00,1,0,1793683908,0),(3,'6个月','',6,240.00,1,0,1793683908,0),(4,'12个月','',12,360.00,1,0,1793683908,0);
/*!40000 ALTER TABLE `kg_vip` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_vod_source`
--

DROP TABLE IF EXISTS `kg_vod_source`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_vod_source` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '源名称',
  `feed_url` varchar(500) NOT NULL DEFAULT '' COMMENT '清单地址(http(s)或本地绝对路径)',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '默认分类编号',
  `course_title` varchar(100) NOT NULL DEFAULT '' COMMENT '默认归入的课程名(空则按清单分组)',
  `published` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '是否启用',
  `last_sync_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '最近同步时间',
  `deleted` int(11) unsigned NOT NULL DEFAULT '0',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_published` (`published`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COMMENT='视频资源同步源';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_vod_source`
--

LOCK TABLES `kg_vod_source` WRITE;
/*!40000 ALTER TABLE `kg_vod_source` DISABLE KEYS */;
INSERT INTO `kg_vod_source` VALUES (1,'演示源','C:/ctc/www/storage/vod_manifest_sample.json',2,'',0,1793753485,0,1793750304,1793753485),(2,'无默认分类源','C:/ctc/www/storage/vod_manifest_bad.json',0,'',0,1793753485,0,1793750332,1793753485),(3,'警院公开课镜像源','C:/ctc/www/storage/vod_manifest_police.json',7,'公安业务基础知识',1,1793757243,0,1793757238,1793757243);
/*!40000 ALTER TABLE `kg_vod_source` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `kg_vod_sync_log`
--

DROP TABLE IF EXISTS `kg_vod_sync_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `kg_vod_sync_log` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `source_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '源编号',
  `external_id` varchar(100) NOT NULL DEFAULT '' COMMENT '上游视频唯一标识',
  `title` varchar(200) NOT NULL DEFAULT '' COMMENT '视频标题',
  `remote_url` varchar(1000) NOT NULL DEFAULT '' COMMENT '远程播放地址',
  `duration` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '时长(秒)',
  `category_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '实际归类分类',
  `course_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '归入课程编号',
  `chapter_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '生成课时编号',
  `status` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '0待处理 1已同步 2已失败',
  `retry_count` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '重试次数',
  `last_error` varchar(500) NOT NULL DEFAULT '' COMMENT '最近错误',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_source_external` (`source_id`,`external_id`),
  KEY `idx_status` (`status`),
  KEY `idx_course` (`course_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COMMENT='视频资源同步日志';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `kg_vod_sync_log`
--

LOCK TABLES `kg_vod_sync_log` WRITE;
/*!40000 ALTER TABLE `kg_vod_sync_log` DISABLE KEYS */;
INSERT INTO `kg_vod_sync_log` VALUES (1,1,'demo-py-001','环境搭建与工具链入门','https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',1250,2,7,38,1,0,'',1793750309,0),(2,1,'demo-py-002','虚拟环境与依赖管理','https://test-streams.mux.dev/pts_shift/master.m3u8',980,2,7,39,1,0,'',1793750309,0),(3,1,'demo-py-003','列表推导与生成器表达式','https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',1500,2,7,41,1,0,'',1793750309,0),(4,1,'demo-py-004','并发编程：从线程到协程','https://test-streams.mux.dev/pts_shift/master.m3u8',2400,2,7,42,1,0,'',1793750309,0),(5,1,'demo-fe-001','未指定分类的条目走源默认分类','https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',660,2,8,44,1,0,'',1793750310,0),(6,2,'demo-badcat-001','分类缺失的条目应失败并记录','https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',0,0,0,0,2,4,'分类缺失：条目未指定有效分类，且源未配置默认分类',1793750340,1793753485),(7,3,'police-001','刑法概述与基本原则','http://127.0.0.1:8000/static/vod/police/criminal-law-intro.mp4',1023,7,9,46,1,0,'',1793757242,0),(8,3,'police-002','犯罪构成与认定','http://127.0.0.1:8000/static/vod/police/crime-constitution.mp4',3624,7,9,47,1,0,'',1793757243,0),(9,3,'police-003','行政处罚法要点','http://127.0.0.1:8000/static/vod/police/admin-penalty.mp4',3237,7,9,49,1,0,'',1793757243,0),(10,3,'police-004','治安管理处罚法（分则）','http://127.0.0.1:8000/static/vod/police/public-order.mp4',3026,7,9,50,1,0,'',1793757243,0);
/*!40000 ALTER TABLE `kg_vod_sync_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'ctc'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-04 17:12:34
