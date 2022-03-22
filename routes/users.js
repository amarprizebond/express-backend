const express = require('express');
const router = express.Router();
const db = require('../dbConnection');
const auth = require('../middleware/auth');
const validator = require('validator');
const { generateToken } = require('../utilities.js');
const dotenv = require('dotenv');
dotenv.config();
const axios = require('axios');
const cheerio = require('cheerio');
const { IncomingWebhook } = require('@slack/webhook');

/**
 * Get user authorization token.
 * @access: public
 * @return: User resource with generated token
 */
router.post('/token', function(req, res, next) {

	const { uid, email, token } = req.body;

	// validating fields
	if ( ! uid || ! email || ! token ) {
		res.status(400).send({
			error: 'INVALID_INPUT',
			message: 'Missing required fields.'
		});
		return next;
	}

	if ( ! validator.isEmail(email) ) {
		res.status(400).send({
			error: 'INVALID_INPUT_EMAIL',
			message: 'Invalid email address.'
		});
		return next;
	}

	// ToDo: need to varify firebase token before generating own token

	const sql = 'SELECT * FROM users WHERE uid = ? AND email = ? AND is_active = 1 LIMIT 1;';
	db.query (
		sql,
		[uid, email],
		function (error, results, fields) {

			// catch sql error
			if (error) {
				res.status(500).send(error);
				return next;
			};

			// empty result, user not found
			if ( results.length <= 0 ) {
				res.status(400).send({
					error: 'INVALID_USER',
					message: 'User not found or inactive.'
				});
				return next;
			}

			const user = results[0];
			user.token = generateToken(user);

			const response = { ...user };
			res.status(200).send(response);

			return next;
		}
	);
});

/* GET users listing. */
router.get('/', function(req, res, next) {
	res.send('Get list of all users.');
});

/**
 * Insert/Add/Register new user
 * @access: public
 * @return: User resource with generated token
 */
router.post('/', function(req, res, next) {

	let { uid, email, name, phone } = req.body;

	// validating fields
	if ( ! uid || ! email ) {
		res.status(400).send({
			error: 'INVALID_INPUT',
			message: 'Missing required fields.'
		});
		return next;
	}

	if ( ! validator.isEmail(email) ) {
		res.status(400).send({
			error: 'INVALID_INPUT_EMAIL',
			message: 'Invalid email address.'
		});
		return next;
	}

	name = ! name ? '' : name;
	phone = ! phone ? '' : phone;

	const sql = 'SELECT * FROM users WHERE uid = ? OR email = ? LIMIT 1;';
	db.query(
		sql, [uid, email], (error, results, fields) => {

			// catch sql error
			if (error) {
				res.status(500).send(error);
				return next;
			}

			if ( results.length > 0 ) {
				res.status(400).send({
					error: 'USER_EXISTS',
					message: 'User already exists with this email/uid.'
				});
				return next;
			}

			const data = { uid, email, name, phone, is_active: 1 };
			const insertSql = 'INSERT INTO users SET ?;';
			db.query(insertSql, [data], (error, results, fields) => {

				// catch sql error
				if (error) {
					res.status(500).send(error);
					return next;
				}

				// insert into notificatrion table
				const insertNotificationSql = 'INSERT INTO notifications SET ?;';
				dataNotification = {
					type: 'new user',
					method: 'slack',
					reference: 'New user created using ' + data.email
				};
				db.query(insertNotificationSql, [dataNotification], (error, results, fields) => {});

				let user = {
					id: results.insertId,
					...data,
					role: 'customer'
				};
				
				user.token = generateToken(user);

				const response = { ...user };
				res.send(response);

				return next;
			});
		}
	);

});

/**
 * Get first 10 numbers of userId
 * @access: private
 */
router.get('/numbers', auth, function(req, res, next) {

	const { id } = req;
	const { ps, page, search } = req.query;

	const pageSize = ps || process.env.APP_PAGE_SIZE || 10;
	const pageNumber = validator.toInt( ! page ? '1' : page );
	const limitOffset = (pageNumber - 1) * pageSize;

	// validation
	if ( isNaN(pageNumber) ) {
		res.status(400).send({
			error: 'INVALID_INPUT',
			message: 'Page number must be integer.'
		});
		return next;
	}
	
	const querySql = search ? 'AND number LIKE '+ db.escape('%' + search + '%') : '';
	const sql = 'SELECT * FROM user_numbers, series WHERE user_numbers.series = series.serial AND user_id = ? '+ querySql +' ORDER BY series, number LIMIT ?, '+ pageSize +';' +
			    'SELECT COUNT(*) AS count FROM user_numbers WHERE user_id = ? '+ querySql +';' +
			    'SELECT COUNT(*) AS total FROM user_numbers WHERE user_id = ?;';
	db.query(
		sql, 
		[id, limitOffset, id, id],
		function (error, results, fields) {

			// catch sql error
			if (error) {
				res.status(500).send(error);
				return next;
			}

			let response = {
				data: results[0],
				total_count: results[1][0].count,
				total_record: results[2][0].total
			}

			res.send( response );
			return next;
		}
	);

});

/**
 * Get user resource by user id/uid/email
 * @access: private
 */
router.get('/:idOrEmail', auth, function(req, res, next) {

	const idOrEmail = req.params.idOrEmail;
	let sql = '';

	if ( validator.isEmail(idOrEmail) ) {
		sql = 'SELECT * FROM users WHERE email = ? AND is_active = 1 LIMIT 1';
	} else if ( validator.isInt(idOrEmail) ) {
		sql = 'SELECT * FROM users WHERE id = ? AND is_active = 1 LIMIT 1';
	} else {
		sql = 'SELECT * FROM users WHERE uid = ? AND is_active = 1 LIMIT 1';
	}
	
	db.query(
		sql, 
		[idOrEmail],
		function (error, results, fields) {

			// catch sql error
			if (error) {
				res.status(500).send(error);
				return next;
			};

			// empty result, user not found
			if ( results.length <= 0 ) {
				res.status(400).send({
					error: 'INVALID_USER',
					message: 'User not found or inactive.'
				});
				return next;
			}

			const user = results[0];

			const response = { ...user };
			res.status(200).send(response);

			return next;
		}
	);

});

/**
 * Insert :number for userId
 * @access: auth
 */
router.post('/numbers', auth, function(req, res, next) {

	const { id } = req;
	let { series, number } = req.body;

	// validation
	if ( ! series || ! number ) {
		res.status(400).send({
			error: 'INVALID_INPUT',
			message: 'Missing required fields.'
		});
		return next;
	}

	if ( ! validator.isInt(series.toString(), { min: 1, max: 62 }) || ! validator.isInt(number.toString(), { min: 1, max: 9999999 }) ) {
		res.status(400).send({
			error: 'INVALID_INPUT_DATA',
			message: 'Values are not integer or out of range. Series should be between 1-62. Number should be between 1-9999999.'
		});
		return next;
	}

	series = validator.toInt(series.toString());
	number = validator.toInt(number.toString());

	const sql = 'SELECT * FROM user_numbers WHERE user_id = ? AND series = ? AND number = ? LIMIT 1;';
	db.query(
		sql, [id, series, number], (error, results, fields) => {

			// catch sql error
			if (error) {
				res.status(500).send(error);
				return next;
			}

			// validation; number already exists
			if ( results.length > 0 ) {
				res.status(400).send({
					error: 'NUMBER_EXISTS',
					message: 'Number already exists.'
				});
				return next;
			}

			const data = {
				user_id: id,
				series,
				number
			};
			
			const insertSql = 'INSERT INTO user_numbers SET ?;';
			db.query(insertSql, [data], (error, results, fields) => {

				// catch sql error
				if (error) {
					res.status(500).send(error);
					return next;
				}

				const response = {
					id: results.insertId,
					...data
				}

				res.send(response);
				return next;
			});

		}
	);
});

/**
 * Delete :number for userId
 * @access: auth
 */
router.delete('/numbers', auth, function(req, res, next) {

	const user_id = req.id;
	let { id, series, number } = req.body;	

	// validation
	if ( ! series || ! number ) {
		res.status(400).send({
			error: 'INVALID_INPUT',
			message: 'Missing required fields.'
		});
		return next;
	}

	if ( ! validator.isInt(series.toString(), { min: 1, max: 62 }) || ! validator.isInt(number.toString(), { min: 1, max: 9999999 }) ) {
		res.status(400).send({
			error: 'INVALID_INPUT_DATA',
			message: 'Values are not integer or out of range. Series should be between 1-62. Number should be between 1-9999999.'
		});
		return next;
	}

	series = validator.toInt(series.toString());
	number = validator.toInt(number.toString());

	const sql = 'DELETE FROM user_numbers WHERE user_id = ? AND series = ? AND number = ?;';
	db.query(
		sql, [user_id, series, number], (error, results, fields) => {

			// catch sql error
			if (error) {
				res.status(500).send(error);
				return next;
			}

			if ( results.affectedRows == 0 ) {
				res.status(400).send({
					error: 'NUMBER_DELETE_NONE',
					message: 'No number deleted. Probably number does not exists.'
				});
				return next;
			}

			if ( results.affectedRows == 1 ) {

				const response = {
					id,
					user_id,
					series,
					number,
					result: true,
				};
				
				res.send(response);
				return next;

			} else {
				// TODO: Log the issue, raise warning
				res.status(400).send({
					error: 'NUMBER_DELETE_MANY',
					message: 'More than one number deleted.'
				});
				return next;
			}
		}
	);
});

module.exports = router;
