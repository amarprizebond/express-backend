/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Dumping structure for event prizebond.event_cron_process
DELIMITER //
CREATE DEFINER=`homestead`@`%` EVENT `event_cron_process` ON SCHEDULE EVERY 10 SECOND STARTS '2020-07-25 18:32:29' ON COMPLETION PRESERVE ENABLE DO BEGIN
	CALL proc_check_user_numbers(100);
	CALL proc_check_result_numbers(100);
END//
DELIMITER ;

-- Dumping structure for event prizebond.event_daily
DELIMITER //
CREATE DEFINER=`homestead`@`%` EVENT `event_daily` ON SCHEDULE EVERY 1 DAY STARTS '2020-07-25 00:00:01' ON COMPLETION PRESERVE ENABLE DO BEGIN
	CALL proc_check_results();
END//
DELIMITER ;

-- Dumping structure for table prizebond.notifications
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `source` varchar(20) NOT NULL DEFAULT '' COMMENT 'user_numbers',
  `method` varchar(20) NOT NULL DEFAULT '' COMMENT 'email, sms',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT 'pending, completed, failed',
  `user_numbers_id` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- Dumping data for table prizebond.notifications: ~0 rows (approximately)
DELETE FROM `notifications`;

-- Dumping structure for table prizebond.prizes
CREATE TABLE IF NOT EXISTS `prizes` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `prize` tinyint(3) unsigned NOT NULL,
  `value` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4;

-- Dumping data for table prizebond.prizes: ~4 rows (approximately)
DELETE FROM `prizes`;
/*!40000 ALTER TABLE `prizes` DISABLE KEYS */;
INSERT INTO `prizes` (`id`, `prize`, `value`) VALUES
	(1, 1, 600000),
	(2, 2, 325000),
	(3, 3, 100000),
	(4, 4, 50000),
	(5, 5, 10000);
/*!40000 ALTER TABLE `prizes` ENABLE KEYS */;

-- Dumping structure for procedure prizebond.proc_check_results
DELIMITER //
CREATE DEFINER=`homestead`@`%` PROCEDURE `proc_check_results`()
BEGIN

	DECLARE var_result_serial SMALLINT(5) DEFAULT 0;

	loop_result:  LOOP
	
		-- check if a result is outdated and update result_numbers where is_valid = 1
		-- should be everyday at midnight
		-- results are valid for two years
		SET var_result_serial = 0;
		SELECT serial INTO var_result_serial FROM results WHERE pub_date < DATE_SUB(NOW(), INTERVAL 2 YEAR) AND is_valid = 1 LIMIT 1;
		
		UPDATE results SET is_valid = 0 WHERE serial = var_result_serial;
		UPDATE result_numbers SET is_valid = 0 WHERE result_serial = var_result_serial;
		
		SELECT var_result_serial;
		
		IF var_result_serial <= 0 THEN 
			LEAVE  loop_result;
		END  IF;

	END LOOP;
	
END//
DELIMITER ;

-- Dumping structure for procedure prizebond.proc_check_result_numbers
DELIMITER //
CREATE DEFINER=`homestead`@`%` PROCEDURE `proc_check_result_numbers`(
	IN `cursor_size` INT
)
BEGIN
	DECLARE var_result_numbers_id INT(11);
	DECLARE var_result_numbers_number INT(11);
	DECLARE var_user_numbers_id INT(11);
	
	-- select 100 rows from result_numbers table where is_checked = 0, is_valid = 1
	DECLARE var_exit_loop BOOLEAN DEFAULT FALSE;
	DECLARE cursor_check_result_numbers CURSOR FOR
		SELECT id, number FROM result_numbers WHERE is_checked = 0 AND is_valid = 1 LIMIT cursor_size;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET var_exit_loop = TRUE;
	
	OPEN cursor_check_result_numbers;
	
	-- loop through the resultset
	cursor_check_result_numbers_loop: LOOP
   	set var_exit_loop = false;
		FETCH cursor_check_result_numbers INTO var_result_numbers_id, var_result_numbers_number;
		
   	IF var_exit_loop THEN
      	CLOSE cursor_check_result_numbers;
         LEAVE cursor_check_result_numbers_loop;
   	END IF;
   	
		-- for each row, take the number and try to match with user_numbers table
		-- if match found, then do the following,
		-- 1. insert a row in notifications table
		-- 2. update user_numbers table row with result_numbers_id
		-- 3. update result_numbers table row with is_checked = 1
		-- if no match found, update result_numbers table with is_checked = 1
		SET var_user_numbers_id = null;
		SELECT id INTO var_user_numbers_id FROM user_numbers WHERE number = var_result_numbers_number LIMIT 1;
   	
   	UPDATE result_numbers SET is_checked = 1 WHERE id = var_result_numbers_id;
   	UPDATE user_numbers SET result_numbers_id = var_result_numbers_id WHERE id = var_user_numbers_id;
   	
   	IF var_user_numbers_id THEN
   		INSERT INTO notifications (source, method, user_numbers_id) VALUES ('user_numbers', 'email', var_user_numbers_id);
   	END IF;
   	
   END LOOP cursor_check_result_numbers_loop;


END//
DELIMITER ;

-- Dumping structure for procedure prizebond.proc_check_user_numbers
DELIMITER //
CREATE DEFINER=`homestead`@`%` PROCEDURE `proc_check_user_numbers`(
	IN `cursor_size` INT
)
BEGIN
	DECLARE var_user_numbers_id INT(11);
	DECLARE var_user_numbers_number INT(11);
	DECLARE var_result_numbers_id INT(11);
	
	-- select 100 rows from user_numbers table where is_checked = 0
	DECLARE var_exit_loop BOOLEAN DEFAULT FALSE;
	DECLARE cursor_check_user_numbers CURSOR FOR
		SELECT id, number FROM user_numbers WHERE is_checked = 0 LIMIT cursor_size;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET var_exit_loop = TRUE;
	
	OPEN cursor_check_user_numbers;
	
	-- loop through the resultset
	cursor_check_user_numbers_loop: LOOP
   	set var_exit_loop = false;
		FETCH cursor_check_user_numbers INTO var_user_numbers_id, var_user_numbers_number;
		
   	IF var_exit_loop THEN
      	CLOSE cursor_check_user_numbers;
         LEAVE cursor_check_user_numbers_loop;
   	END IF;
   	
		-- for each row, take the number and try to match with result_numbers table where is_valid = 1
		-- if match found, then do the following,
		-- 1. insert a row in notifications table
		-- 2. update user_numbers table row with result_numbers_id and is_checked = 1
		-- if no match found, update user_numbers table with is_checked = 1
		SET var_result_numbers_id = null;
		SELECT id INTO var_result_numbers_id FROM result_numbers WHERE number = var_user_numbers_number AND is_valid = 1 LIMIT 1;
   	
   	UPDATE user_numbers SET is_checked = 1, result_numbers_id = var_result_numbers_id WHERE id = var_user_numbers_id;
   	
   	IF var_result_numbers_id THEN
   		INSERT INTO notifications (source, method, user_numbers_id) VALUES ('user_numbers', 'email', var_user_numbers_id);
   	END IF;
   	
   END LOOP cursor_check_user_numbers_loop;
END//
DELIMITER ;

-- Dumping structure for table prizebond.results
CREATE TABLE IF NOT EXISTS `results` (
  `serial` smallint(5) unsigned NOT NULL,
  `pub_date` date DEFAULT NULL,
  `is_valid` tinyint(1) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Dumping data for table prizebond.results: ~10 rows (approximately)
DELETE FROM `results`;
/*!40000 ALTER TABLE `results` DISABLE KEYS */;
INSERT INTO `results` (`serial`, `pub_date`, `is_valid`) VALUES
	(90, '2017-10-31', 0),
	(91, '2018-04-30', 0),
	(92, '2018-07-31', 0),
	(93, '2018-10-31', 1),
	(94, '2019-01-31', 1),
	(95, '2019-04-30', 1),
	(96, '2019-07-31', 1),
	(97, '2019-10-31', 1),
	(98, '2020-02-02', 1),
	(99, '2020-06-04', 1);
/*!40000 ALTER TABLE `results` ENABLE KEYS */;

-- Dumping structure for table prizebond.result_numbers
CREATE TABLE IF NOT EXISTS `result_numbers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `result_serial` smallint(5) unsigned NOT NULL,
  `prize_id` tinyint(3) unsigned NOT NULL,
  `number` int(11) unsigned NOT NULL,
  `is_checked` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `is_valid` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT 'result number is valid till two years',
  PRIMARY KEY (`id`),
  KEY `number` (`number`),
  KEY `FK_result_numbers_prizes` (`prize_id`),
  KEY `FK_result_numbers_results` (`result_serial`),
  CONSTRAINT `FK_result_numbers_prizes` FOREIGN KEY (`prize_id`) REFERENCES `prizes` (`id`),
  CONSTRAINT `FK_result_numbers_results` FOREIGN KEY (`result_serial`) REFERENCES `results` (`serial`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=461 DEFAULT CHARSET=utf8mb4;

-- Dumping data for table prizebond.result_numbers: ~460 rows (approximately)
DELETE FROM `result_numbers`;
/*!40000 ALTER TABLE `result_numbers` DISABLE KEYS */;
INSERT INTO `result_numbers` (`id`, `result_serial`, `prize_id`, `number`, `is_checked`, `is_valid`) VALUES
	(1, 98, 1, 611563, 1, 1),
	(2, 98, 2, 648355, 1, 1),
	(3, 98, 3, 103610, 1, 1),
	(4, 98, 3, 272756, 1, 1),
	(5, 98, 4, 104639, 1, 1),
	(6, 98, 4, 827159, 1, 1),
	(7, 98, 5, 6246, 1, 1),
	(8, 98, 5, 24106, 1, 1),
	(9, 98, 5, 48355, 1, 1),
	(10, 98, 5, 48399, 1, 1),
	(11, 98, 5, 50677, 1, 1),
	(12, 98, 5, 99886, 1, 1),
	(13, 98, 5, 143033, 1, 1),
	(14, 98, 5, 159425, 1, 1),
	(15, 98, 5, 167227, 1, 1),
	(16, 98, 5, 202465, 1, 1),
	(17, 98, 5, 221834, 1, 1),
	(18, 98, 5, 270055, 1, 1),
	(19, 98, 5, 291429, 1, 1),
	(20, 98, 5, 295994, 1, 1),
	(21, 98, 5, 319375, 1, 1),
	(22, 98, 5, 330785, 1, 1),
	(23, 98, 5, 347712, 1, 1),
	(24, 98, 5, 452475, 1, 1),
	(25, 98, 5, 471363, 1, 1),
	(26, 98, 5, 520753, 1, 1),
	(27, 98, 5, 562731, 1, 1),
	(28, 98, 5, 627302, 1, 1),
	(29, 98, 5, 634206, 1, 1),
	(30, 98, 5, 726209, 1, 1),
	(31, 98, 5, 736956, 1, 1),
	(32, 98, 5, 757138, 1, 1),
	(33, 98, 5, 764906, 1, 1),
	(34, 98, 5, 779957, 1, 1),
	(35, 98, 5, 789929, 1, 1),
	(36, 98, 5, 815759, 1, 1),
	(37, 98, 5, 827080, 1, 1),
	(38, 98, 5, 832960, 1, 1),
	(39, 98, 5, 838741, 1, 1),
	(40, 98, 5, 845271, 1, 1),
	(41, 98, 5, 854996, 1, 1),
	(42, 98, 5, 872212, 1, 1),
	(43, 98, 5, 882831, 1, 1),
	(44, 98, 5, 926013, 1, 1),
	(45, 98, 5, 952660, 1, 1),
	(46, 98, 5, 978683, 1, 1),
	(47, 97, 1, 349364, 1, 1),
	(48, 97, 2, 396932, 1, 1),
	(49, 97, 3, 468649, 1, 1),
	(50, 97, 3, 704413, 1, 1),
	(51, 97, 4, 874444, 1, 1),
	(52, 97, 4, 965453, 1, 1),
	(53, 97, 5, 5674, 1, 1),
	(54, 97, 5, 33453, 1, 1),
	(55, 97, 5, 52312, 1, 1),
	(56, 97, 5, 93043, 1, 1),
	(57, 97, 5, 141278, 1, 1),
	(58, 97, 5, 188779, 1, 1),
	(59, 97, 5, 198292, 1, 1),
	(60, 97, 5, 243846, 1, 1),
	(61, 97, 5, 306645, 1, 1),
	(62, 97, 5, 308519, 1, 1),
	(63, 97, 5, 327083, 1, 1),
	(64, 97, 5, 439052, 1, 1),
	(65, 97, 5, 452136, 1, 1),
	(66, 97, 5, 498364, 1, 1),
	(67, 97, 5, 527054, 1, 1),
	(68, 97, 5, 535920, 1, 1),
	(69, 97, 5, 546747, 1, 1),
	(70, 97, 5, 560609, 1, 1),
	(71, 97, 5, 564620, 1, 1),
	(72, 97, 5, 574912, 1, 1),
	(73, 97, 5, 624683, 1, 1),
	(74, 97, 5, 628858, 1, 1),
	(75, 97, 5, 632182, 1, 1),
	(76, 97, 5, 661374, 1, 1),
	(77, 97, 5, 695241, 1, 1),
	(78, 97, 5, 708073, 1, 1),
	(79, 97, 5, 723969, 1, 1),
	(80, 97, 5, 734509, 1, 1),
	(81, 97, 5, 737468, 1, 1),
	(82, 97, 5, 765123, 1, 1),
	(83, 97, 5, 768576, 1, 1),
	(84, 97, 5, 795280, 1, 1),
	(85, 97, 5, 841496, 1, 1),
	(86, 97, 5, 845688, 1, 1),
	(87, 97, 5, 876085, 1, 1),
	(88, 97, 5, 891735, 1, 1),
	(89, 97, 5, 895536, 1, 1),
	(90, 97, 5, 906282, 1, 1),
	(91, 97, 5, 943208, 1, 1),
	(92, 97, 5, 968892, 1, 1),
	(93, 96, 1, 617898, 1, 1),
	(94, 96, 2, 417722, 1, 1),
	(95, 96, 3, 176832, 1, 1),
	(96, 96, 3, 781796, 1, 1),
	(97, 96, 4, 109153, 1, 1),
	(98, 96, 4, 901014, 1, 1),
	(99, 96, 5, 13308, 1, 1),
	(100, 96, 5, 13807, 1, 1),
	(101, 96, 5, 27029, 1, 1),
	(102, 96, 5, 57882, 1, 1),
	(103, 96, 5, 76883, 1, 1),
	(104, 96, 5, 139833, 1, 1),
	(105, 96, 5, 186484, 1, 1),
	(106, 96, 5, 190730, 1, 1),
	(107, 96, 5, 250897, 1, 1),
	(108, 96, 5, 256880, 1, 1),
	(109, 96, 5, 278120, 1, 1),
	(110, 96, 5, 292235, 1, 1),
	(111, 96, 5, 352529, 1, 1),
	(112, 96, 5, 369607, 1, 1),
	(113, 96, 5, 399925, 1, 1),
	(114, 96, 5, 418553, 1, 1),
	(115, 96, 5, 424035, 1, 1),
	(116, 96, 5, 483623, 1, 1),
	(117, 96, 5, 501729, 1, 1),
	(118, 96, 5, 508074, 1, 1),
	(119, 96, 5, 567060, 1, 1),
	(120, 96, 5, 569165, 1, 1),
	(121, 96, 5, 578374, 1, 1),
	(122, 96, 5, 592788, 1, 1),
	(123, 96, 5, 619201, 1, 1),
	(124, 96, 5, 630459, 1, 1),
	(125, 96, 5, 644376, 1, 1),
	(126, 96, 5, 701091, 1, 1),
	(127, 96, 5, 701307, 1, 1),
	(128, 96, 5, 708143, 1, 1),
	(129, 96, 5, 712495, 1, 1),
	(130, 96, 5, 730421, 1, 1),
	(131, 96, 5, 753495, 1, 1),
	(132, 96, 5, 773141, 1, 1),
	(133, 96, 5, 871006, 1, 1),
	(134, 96, 5, 875372, 1, 1),
	(135, 96, 5, 893185, 1, 1),
	(136, 96, 5, 908309, 1, 1),
	(137, 96, 5, 917649, 1, 1),
	(138, 96, 5, 925909, 1, 1),
	(139, 95, 1, 154475, 1, 1),
	(140, 95, 2, 809993, 1, 1),
	(141, 95, 3, 241145, 1, 1),
	(142, 95, 3, 438384, 1, 1),
	(143, 95, 4, 527364, 1, 1),
	(144, 95, 4, 590716, 1, 1),
	(145, 95, 5, 65446, 1, 1),
	(146, 95, 5, 66918, 1, 1),
	(147, 95, 5, 69628, 1, 1),
	(148, 95, 5, 75655, 1, 1),
	(149, 95, 5, 111685, 1, 1),
	(150, 95, 5, 132811, 1, 1),
	(151, 95, 5, 148262, 1, 1),
	(152, 95, 5, 191368, 1, 1),
	(153, 95, 5, 191918, 1, 1),
	(154, 95, 5, 226694, 1, 1),
	(155, 95, 5, 231877, 1, 1),
	(156, 95, 5, 233856, 1, 1),
	(157, 95, 5, 259891, 1, 1),
	(158, 95, 5, 295878, 1, 1),
	(159, 95, 5, 297210, 1, 1),
	(160, 95, 5, 328897, 1, 1),
	(161, 95, 5, 400736, 1, 1),
	(162, 95, 5, 426771, 1, 1),
	(163, 95, 5, 437924, 1, 1),
	(164, 95, 5, 444048, 1, 1),
	(165, 95, 5, 541317, 1, 1),
	(166, 95, 5, 546102, 1, 1),
	(167, 95, 5, 556283, 1, 1),
	(168, 95, 5, 565930, 1, 1),
	(169, 95, 5, 637860, 1, 1),
	(170, 95, 5, 675713, 1, 1),
	(171, 95, 5, 693065, 1, 1),
	(172, 95, 5, 749778, 1, 1),
	(173, 95, 5, 752781, 1, 1),
	(174, 95, 5, 770016, 1, 1),
	(175, 95, 5, 782832, 1, 1),
	(176, 95, 5, 786580, 1, 1),
	(177, 95, 5, 828464, 1, 1),
	(178, 95, 5, 847314, 1, 1),
	(179, 95, 5, 887018, 1, 1),
	(180, 95, 5, 906314, 1, 1),
	(181, 95, 5, 936153, 1, 1),
	(182, 95, 5, 946571, 1, 1),
	(183, 95, 5, 948355, 1, 1),
	(184, 95, 5, 977576, 1, 1),
	(185, 94, 1, 609454, 1, 1),
	(186, 94, 2, 82870, 1, 1),
	(187, 94, 3, 777127, 1, 1),
	(188, 94, 3, 176392, 1, 1),
	(189, 94, 4, 327261, 1, 1),
	(190, 94, 4, 401044, 1, 1),
	(191, 94, 5, 55351, 1, 1),
	(192, 94, 5, 106515, 1, 1),
	(193, 94, 5, 155117, 1, 1),
	(194, 94, 5, 167426, 1, 1),
	(195, 94, 5, 186327, 1, 1),
	(196, 94, 5, 188676, 1, 1),
	(197, 94, 5, 202501, 1, 1),
	(198, 94, 5, 204520, 1, 1),
	(199, 94, 5, 224050, 1, 1),
	(200, 94, 5, 245470, 1, 1),
	(201, 94, 5, 303194, 1, 1),
	(202, 94, 5, 314996, 1, 1),
	(203, 94, 5, 346844, 1, 1),
	(204, 94, 5, 351078, 1, 1),
	(205, 94, 5, 355550, 1, 1),
	(206, 94, 5, 358733, 1, 1),
	(207, 94, 5, 407254, 1, 1),
	(208, 94, 5, 414226, 1, 1),
	(209, 94, 5, 471752, 1, 1),
	(210, 94, 5, 480738, 1, 1),
	(211, 94, 5, 530035, 1, 1),
	(212, 94, 5, 531956, 1, 1),
	(213, 94, 5, 548363, 1, 1),
	(214, 94, 5, 572430, 1, 1),
	(215, 94, 5, 602549, 1, 1),
	(216, 94, 5, 609268, 1, 1),
	(217, 94, 5, 717968, 1, 1),
	(218, 94, 5, 731632, 1, 1),
	(219, 94, 5, 744527, 1, 1),
	(220, 94, 5, 757768, 1, 1),
	(221, 94, 5, 760091, 1, 1),
	(222, 94, 5, 844844, 1, 1),
	(223, 94, 5, 849708, 1, 1),
	(224, 94, 5, 920311, 1, 1),
	(225, 94, 5, 953587, 1, 1),
	(226, 94, 5, 955412, 1, 1),
	(227, 94, 5, 957202, 1, 1),
	(228, 94, 5, 972975, 1, 1),
	(229, 94, 5, 994537, 1, 1),
	(230, 94, 5, 998999, 1, 1),
	(231, 93, 1, 420224, 1, 1),
	(232, 93, 2, 75374, 1, 1),
	(233, 93, 3, 328642, 1, 1),
	(234, 93, 3, 685755, 1, 1),
	(235, 93, 4, 524239, 1, 1),
	(236, 93, 4, 583110, 1, 1),
	(237, 93, 5, 7591, 1, 1),
	(238, 93, 5, 39890, 1, 1),
	(239, 93, 5, 72427, 1, 1),
	(240, 93, 5, 75689, 1, 1),
	(241, 93, 5, 112254, 1, 1),
	(242, 93, 5, 118354, 1, 1),
	(243, 93, 5, 215525, 1, 1),
	(244, 93, 5, 266367, 1, 1),
	(245, 93, 5, 290778, 1, 1),
	(246, 93, 5, 308732, 1, 1),
	(247, 93, 5, 393075, 1, 1),
	(248, 93, 5, 422036, 1, 1),
	(249, 93, 5, 430021, 1, 1),
	(250, 93, 5, 452550, 1, 1),
	(251, 93, 5, 456731, 1, 1),
	(252, 93, 5, 467888, 1, 1),
	(253, 93, 5, 480534, 1, 1),
	(254, 93, 5, 488098, 1, 1),
	(255, 93, 5, 526184, 1, 1),
	(256, 93, 5, 532289, 1, 1),
	(257, 93, 5, 572999, 1, 1),
	(258, 93, 5, 650340, 1, 1),
	(259, 93, 5, 653239, 1, 1),
	(260, 93, 5, 653980, 1, 1),
	(261, 93, 5, 671761, 1, 1),
	(262, 93, 5, 685847, 1, 1),
	(263, 93, 5, 693378, 1, 1),
	(264, 93, 5, 741193, 1, 1),
	(265, 93, 5, 768128, 1, 1),
	(266, 93, 5, 778405, 1, 1),
	(267, 93, 5, 794360, 1, 1),
	(268, 93, 5, 815984, 1, 1),
	(269, 93, 5, 838057, 1, 1),
	(270, 93, 5, 891462, 1, 1),
	(271, 93, 5, 913592, 1, 1),
	(272, 93, 5, 926244, 1, 1),
	(273, 93, 5, 934840, 1, 1),
	(274, 93, 5, 952178, 1, 1),
	(275, 93, 5, 982165, 1, 1),
	(276, 93, 5, 988779, 1, 1),
	(277, 92, 1, 339267, 1, 0),
	(278, 92, 2, 764640, 1, 0),
	(279, 92, 3, 544684, 1, 0),
	(280, 92, 3, 825317, 1, 0),
	(281, 92, 4, 425845, 1, 0),
	(282, 92, 4, 767743, 1, 0),
	(283, 92, 5, 22011, 1, 0),
	(284, 92, 5, 68934, 1, 0),
	(285, 92, 5, 83024, 1, 0),
	(286, 92, 5, 163747, 1, 0),
	(287, 92, 5, 174597, 1, 0),
	(288, 92, 5, 177419, 1, 0),
	(289, 92, 5, 181853, 1, 0),
	(290, 92, 5, 225921, 1, 0),
	(291, 92, 5, 227049, 1, 0),
	(292, 92, 5, 241861, 1, 0),
	(293, 92, 5, 242141, 1, 0),
	(294, 92, 5, 257610, 1, 0),
	(295, 92, 5, 289874, 1, 0),
	(296, 92, 5, 321391, 1, 0),
	(297, 92, 5, 322085, 1, 0),
	(298, 92, 5, 329003, 1, 0),
	(299, 92, 5, 358410, 1, 0),
	(300, 92, 5, 409508, 1, 0),
	(301, 92, 5, 440138, 1, 0),
	(302, 92, 5, 519335, 1, 0),
	(303, 92, 5, 544769, 1, 0),
	(304, 92, 5, 556218, 1, 0),
	(305, 92, 5, 561824, 1, 0),
	(306, 92, 5, 573330, 1, 0),
	(307, 92, 5, 583778, 1, 0),
	(308, 92, 5, 597893, 1, 0),
	(309, 92, 5, 603480, 1, 0),
	(310, 92, 5, 655071, 1, 0),
	(311, 92, 5, 657978, 1, 0),
	(312, 92, 5, 717194, 1, 0),
	(313, 92, 5, 717442, 1, 0),
	(314, 92, 5, 817286, 1, 0),
	(315, 92, 5, 833180, 1, 0),
	(316, 92, 5, 868992, 1, 0),
	(317, 92, 5, 872478, 1, 0),
	(318, 92, 5, 909494, 1, 0),
	(319, 92, 5, 914041, 1, 0),
	(320, 92, 5, 923241, 1, 0),
	(321, 92, 5, 954967, 1, 0),
	(322, 92, 5, 958567, 1, 0),
	(323, 91, 1, 761011, 0, 0),
	(324, 91, 2, 174009, 0, 0),
	(325, 91, 3, 576225, 0, 0),
	(326, 91, 3, 613448, 0, 0),
	(327, 91, 4, 244283, 0, 0),
	(328, 91, 4, 379255, 0, 0),
	(329, 91, 5, 43091, 0, 0),
	(330, 91, 5, 100404, 0, 0),
	(331, 91, 5, 129284, 0, 0),
	(332, 91, 5, 159287, 0, 0),
	(333, 91, 5, 195886, 0, 0),
	(334, 91, 5, 207061, 0, 0),
	(335, 91, 5, 227924, 0, 0),
	(336, 91, 5, 237014, 0, 0),
	(337, 91, 5, 283584, 0, 0),
	(338, 91, 5, 304171, 0, 0),
	(339, 91, 5, 335119, 0, 0),
	(340, 91, 5, 372666, 0, 0),
	(341, 91, 5, 399006, 0, 0),
	(342, 91, 5, 400591, 0, 0),
	(343, 91, 5, 425440, 0, 0),
	(344, 91, 5, 432815, 0, 0),
	(345, 91, 5, 458365, 0, 0),
	(346, 91, 5, 482478, 0, 0),
	(347, 91, 5, 491103, 0, 0),
	(348, 91, 5, 491577, 0, 0),
	(349, 91, 5, 506390, 0, 0),
	(350, 91, 5, 547817, 0, 0),
	(351, 91, 5, 569654, 0, 0),
	(352, 91, 5, 635622, 0, 0),
	(353, 91, 5, 642676, 0, 0),
	(354, 91, 5, 669165, 0, 0),
	(355, 91, 5, 678986, 0, 0),
	(356, 91, 5, 686719, 0, 0),
	(357, 91, 5, 704249, 0, 0),
	(358, 91, 5, 708291, 0, 0),
	(359, 91, 5, 710622, 0, 0),
	(360, 91, 5, 727378, 0, 0),
	(361, 91, 5, 779239, 0, 0),
	(362, 91, 5, 801286, 0, 0),
	(363, 91, 5, 853815, 0, 0),
	(364, 91, 5, 871472, 0, 0),
	(365, 91, 5, 880186, 0, 0),
	(366, 91, 5, 915235, 0, 0),
	(367, 91, 5, 965010, 0, 0),
	(368, 91, 5, 977457, 0, 0),
	(369, 90, 1, 429121, 0, 0),
	(370, 90, 2, 924530, 0, 0),
	(371, 90, 3, 230605, 0, 0),
	(372, 90, 3, 376930, 0, 0),
	(373, 90, 4, 444582, 0, 0),
	(374, 90, 4, 588924, 0, 0),
	(375, 90, 5, 12158, 0, 0),
	(376, 90, 5, 35909, 0, 0),
	(377, 90, 5, 49809, 0, 0),
	(378, 90, 5, 57679, 0, 0),
	(379, 90, 5, 149304, 0, 0),
	(380, 90, 5, 182456, 0, 0),
	(381, 90, 5, 199506, 0, 0),
	(382, 90, 5, 259716, 0, 0),
	(383, 90, 5, 263718, 0, 0),
	(384, 90, 5, 265852, 0, 0),
	(385, 90, 5, 275012, 0, 0),
	(386, 90, 5, 275763, 0, 0),
	(387, 90, 5, 312107, 0, 0),
	(388, 90, 5, 313396, 0, 0),
	(389, 90, 5, 330836, 0, 0),
	(390, 90, 5, 336706, 0, 0),
	(391, 90, 5, 344355, 0, 0),
	(392, 90, 5, 369641, 0, 0),
	(393, 90, 5, 386962, 0, 0),
	(394, 90, 5, 443091, 0, 0),
	(395, 90, 5, 461932, 0, 0),
	(396, 90, 5, 468019, 0, 0),
	(397, 90, 5, 486708, 0, 0),
	(398, 90, 5, 497159, 0, 0),
	(399, 90, 5, 548951, 0, 0),
	(400, 90, 5, 549956, 0, 0),
	(401, 90, 5, 592212, 0, 0),
	(402, 90, 5, 617012, 0, 0),
	(403, 90, 5, 619744, 0, 0),
	(404, 90, 5, 641471, 0, 0),
	(405, 90, 5, 686812, 0, 0),
	(406, 90, 5, 730138, 0, 0),
	(407, 90, 5, 756045, 0, 0),
	(408, 90, 5, 790951, 0, 0),
	(409, 90, 5, 798279, 0, 0),
	(410, 90, 5, 808354, 0, 0),
	(411, 90, 5, 835382, 0, 0),
	(412, 90, 5, 848821, 0, 0),
	(413, 90, 5, 869991, 0, 0),
	(414, 90, 5, 937218, 0, 0),
	(415, 99, 1, 962307, 1, 1),
	(416, 99, 2, 581663, 1, 1),
	(417, 99, 3, 112614, 1, 1),
	(418, 99, 3, 592545, 1, 1),
	(419, 99, 4, 389618, 1, 1),
	(420, 99, 4, 739574, 1, 1),
	(421, 99, 5, 719, 1, 1),
	(422, 99, 5, 45499, 1, 1),
	(423, 99, 5, 51579, 1, 1),
	(424, 99, 5, 95883, 1, 1),
	(425, 99, 5, 154055, 1, 1),
	(426, 99, 5, 171195, 1, 1),
	(427, 99, 5, 222456, 1, 1),
	(428, 99, 5, 293714, 1, 1),
	(429, 99, 5, 407863, 1, 1),
	(430, 99, 5, 460750, 1, 1),
	(431, 99, 5, 470816, 1, 1),
	(432, 99, 5, 484791, 1, 1),
	(433, 99, 5, 510951, 1, 1),
	(434, 99, 5, 527964, 1, 1),
	(435, 99, 5, 551798, 1, 1),
	(436, 99, 5, 565768, 1, 1),
	(437, 99, 5, 616537, 1, 1),
	(438, 99, 5, 640767, 1, 1),
	(439, 99, 5, 655486, 1, 1),
	(440, 99, 5, 684758, 1, 1),
	(441, 99, 5, 712898, 1, 1),
	(442, 99, 5, 716088, 1, 1),
	(443, 99, 5, 718961, 1, 1),
	(444, 99, 5, 722702, 1, 1),
	(445, 99, 5, 753306, 1, 1),
	(446, 99, 5, 763657, 1, 1),
	(447, 99, 5, 791981, 1, 1),
	(448, 99, 5, 800512, 1, 1),
	(449, 99, 5, 803177, 1, 1),
	(450, 99, 5, 811348, 1, 1),
	(451, 99, 5, 815748, 1, 1),
	(452, 99, 5, 822158, 1, 1),
	(453, 99, 5, 834032, 1, 1),
	(454, 99, 5, 865533, 1, 1),
	(455, 99, 5, 897913, 1, 1),
	(456, 99, 5, 907087, 1, 1),
	(457, 99, 5, 935186, 1, 1),
	(458, 99, 5, 938993, 1, 1),
	(459, 99, 5, 949418, 1, 1),
	(460, 99, 5, 996520, 1, 1);
/*!40000 ALTER TABLE `result_numbers` ENABLE KEYS */;

-- Dumping structure for table prizebond.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` varchar(100) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `role` varchar(50) NOT NULL DEFAULT 'customer' COMMENT 'administrator, customer',
  `is_active` tinyint(1) NOT NULL DEFAULT '0',
  `registered` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `uid` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- Dumping data for table prizebond.users: ~1 rows (approximately)
DELETE FROM `users`;

-- Dumping structure for table prizebond.user_numbers
CREATE TABLE IF NOT EXISTS `user_numbers` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) unsigned NOT NULL,
  `series` smallint(5) unsigned DEFAULT NULL COMMENT 'value between 1-58',
  `number` int(11) unsigned NOT NULL COMMENT 'value between 1-9999999',
  `is_checked` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `result_numbers_id` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_user_numbers_users` (`user_id`),
  KEY `number` (`number`),
  CONSTRAINT `FK_user_numbers_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- Dumping data for table prizebond.user_numbers: ~1,003 rows (approximately)
DELETE FROM `user_numbers`;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
