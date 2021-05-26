const createError = require('http-errors');
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
//const sassMiddleware = require('node-sass-middleware');
const nodemailer = require('nodemailer');
const cron = require('node-cron');
const numeral = require('numeral');
const moment = require('moment');
moment.locale('bn');
const dotenv = require('dotenv');
dotenv.config();
const axios = require('axios');
const cheerio = require('cheerio');
const { IncomingWebhook } = require('@slack/webhook');

const db = require('./dbConnection');
const indexRouter = require('./routes/index');
const usersRouter = require('./routes/users');
const resultsRouter = require('./routes/results');
const seriesUtility = require('./utility/seriesUtility');
const numberUtility = require('./utility/numberUtility');

const app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'hbs');

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
/*
app.use(sassMiddleware({
	src: path.join(__dirname, 'public'),
	dest: path.join(__dirname, 'public'),
	indentedSyntax: false, // true = .sass and false = .scss
	sourceMap: true
}));
*/
app.use(express.static(path.join(__dirname, 'public')));

// Add headers
app.use(function (req, res, next) {

	// Website you wish to allow to connect
	res.setHeader('Access-Control-Allow-Origin', '*');

	// Request methods you wish to allow
	res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE');

	// Request headers you wish to allow
	res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With, content-type, Authorization');

	// Set to true if you need the website to include cookies in the requests sent
	// to the API (e.g. in case you use sessions)
	res.setHeader('Access-Control-Allow-Credentials', true);

	// Pass to next layer of middleware
	next();
});

// Routes
app.use('/api/', indexRouter);
app.use('/api/users', usersRouter);
app.use('/api/results', resultsRouter);

// catch 404 and forward to error handler
app.use(function(req, res, next) {
	next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
	// set locals, only providing error in development
	res.locals.message = err.message;
	res.locals.error = req.app.get('env') === 'development' ? err : {};

	// render the error page
	res.status(err.status || 500);
	res.render('error');
});


/**
 * Email notification
 */ 
cron.schedule('*/10 * * * * *', () => {

	const numberUtilityObj = new numberUtility();
	const sql = 'CALL proc_notification_win();';

	db.query(
    	sql, [],
    	function (error, results, fields) {

			// catch sql error
			if (error) {
				// ToDo: Log error
				return;
			}

			// empty result, no notification to process
			if ( typeof results[0] === 'undefined' ) {
				// ToDo: Log error
				return;
				res.status(400).send({
					error: 'NO_NOTIFICATION_FOUND',
					message: 'All notifications are processed.'
				});
			}

			let infos = results[0][0];
			infos.number        = numberUtilityObj.bengaliNumber(numeral(infos.number).format('0000000'));
			infos.series        = seriesUtility.getSeries( infos.series );
			infos.result_serial = numberUtilityObj.bengaliNumberPosition( infos.result_serial );
			infos.result_date   = moment( infos.result_date ).format('Do MMMM, YYYY');
			infos.prize_place   = numberUtilityObj.bengaliNumberPosition( infos.prize_place );
			infos.prize_amount  = numberUtilityObj.bengaliNumber(numeral(infos.prize_amount).format('0,0'));
			infos.app_url       = process.env.APP_BASE_URL;
		
			infos.name = infos.name || infos.email.substring(0, infos.email.lastIndexOf("@"));
			if ( ! infos.email ) {
				return;
			}
      
			app.render('email', { data: infos, layout: false }, function(err, html) {

				if (err) {
					// ToDo: Log error
					return;
				}

				let emailTransporter = null;

				if ( process.env.APP_EMAIL_TRANSPORTER == 'GMAIL' ) {

					emailTransporter = nodemailer.createTransport({
						service: 'gmail',
						host: process.env[process.env.APP_EMAIL_TRANSPORTER + '_HOST'],
						port: process.env[process.env.APP_EMAIL_TRANSPORTER + '_PORT'],
						secure: true, // true for 465, false for other ports
						auth: {
							type: 'OAuth2',
							user: process.env[process.env.APP_EMAIL_TRANSPORTER + '_USER'],
							pass: process.env[process.env.APP_EMAIL_TRANSPORTER + '_PASS'],
							clientId: process.env[process.env.APP_EMAIL_TRANSPORTER + '_CLIENT_ID'],
							clientSecret: process.env[process.env.APP_EMAIL_TRANSPORTER + '_CLIENT_SECRET'],
				            refreshToken: process.env[process.env.APP_EMAIL_TRANSPORTER + '_REFRESH_TOKEN']
						}
					});

				} else {

					emailTransporter = nodemailer.createTransport({
						host: process.env[process.env.APP_EMAIL_TRANSPORTER + '_HOST'],
						port: process.env[process.env.APP_EMAIL_TRANSPORTER + '_PORT'],
						secure: false, // true for 465, false for other ports
						auth: {
							user: process.env[process.env.APP_EMAIL_TRANSPORTER + '_USER'],
							pass: process.env[process.env.APP_EMAIL_TRANSPORTER + '_PASS']
						}
					});
				}				
				
				emailTransporter.sendMail({
					from: `"${process.env.APP_NAME}" <${process.env.APP_FROM_EMAIL}>`,
					to: `"${infos.name}" <${infos.email}>`,
					subject: `অভিনন্দন! আপনি পুরস্কার পেয়েছেন | ${process.env.APP_NAME}`,
					//text: "",
					html: html,
				}, function(error, info) {
				
					let notStatus = '';

					if (error) {
						// ToDo: Log error
						notStatus = 'failed';
					} else {
						notStatus = 'completed';
					}

					const updateSql = 'UPDATE notifications SET status = ? WHERE id = ?;';
					db.query(
						updateSql, [notStatus, infos.notification_id],
						function (error, results, fields) {
							// ToDo: Log error
							return;
						}
					);

				});
			});
		}
	);
	
});

/**
 * Slack notification
 */ 
cron.schedule('*/10 * * * * *', () => {

	const sql = 'SELECT * FROM notifications WHERE status = ? AND method = ? ORDER BY time_added LIMIT 10;';
	db.query(
    	sql, ['pending', 'slack'],
    	function (error, results, fields) {

			// catch sql error
			if (error) {
				// ToDo: Log error
				return;
			}

			const webhook = new IncomingWebhook( process.env.SLACK_WEBHOOK_URL );

			if ( results.length > 0 ) {
				
				results.forEach(function (result) {

					webhook.send({ text: result.reference })
						.then(function(response) {

							const updateQql = 'UPDATE notifications SET status = ? WHERE id = ?;';
							db.query(
								updateQql, ['completed', result.id],
								function (error, results, fields) {}
							);
						})
						.catch(function(error) {

							const updateQql = 'UPDATE notifications SET status = ? WHERE id = ?;';
							db.query(
								updateQql, ['failed', result.id],
								function (error, results, fields) {}
							);

							console.log(error);
							// ToDo: Log error
						});
				});
			}
		}
	);
});

/**
 * New draw slack notification
 */
cron.schedule('* */6 * * *', () => {

	process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0';
	const resultsUrl = process.env.APP_BASE_URL + '/results';

	axios.get(resultsUrl)
	.then(function (response) {

		const results = response.data;
		let latestResultNumber = 0;

		if ( results.total_count > 0 ) {
			latestResultNumber = results.data[0].serial;
		}

		if ( latestResultNumber > 0 ) {

			const bbPrizebondUrl = 'https://www.bb.org.bd/investfacility/prizebond/pbsearch.php';
			axios.get( bbPrizebondUrl, { strictSSL: false })
				.then(function (response) {
					
					const $ = cheerio.load(response.data);
					const tds = $('.rpanel td');
					
					tds.each(function(i, elem) {
						const drawNumber = parseInt( $(elem).find('a').text() );
						if ( ! isNaN(drawNumber) ) {

							if ( drawNumber > latestResultNumber ) {

								const webhook = new IncomingWebhook( process.env.SLACK_WEBHOOK_URL );
								webhook.send({ text: `Prizebond draw number ${drawNumber} published.` })
									.then(function(response) {  })
									.catch(function(error) { console.log(error); });
							}
						}
					});
				})
				.catch(function (error) {
	
					console.log('Error parsing BB site');
					console.log(error);

					const errMessage = `Error parsing Bangladesh Bank site. \n${error.message} [${error.code}]`;
					const webhook = new IncomingWebhook( process.env.SLACK_WEBHOOK_URL );
					webhook.send({ text: errMessage })
						.then(function(response) {  })
						.catch(function(error) { console.log(error); });
				});
		}

	})
	.catch(function (error) {
		console.log('Error returning API call');
		console.log(error);
	});

});

module.exports = app;
