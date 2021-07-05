const express = require('express');
const router = express.Router();
const dotenv = require('dotenv');
dotenv.config();
const axios = require('axios');
const { IncomingWebhook } = require('@slack/webhook');
const nodemailer = require('nodemailer');


/* GET users listing. */
router.get('/', function(req, res, next) {
	res.send('One shoule know what they are doing.');
});


/**
 * Test email functionality, send results to slack.
 */
router.get('/email', function(req, res, next) {

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
		to: `"Arif Uddin" <mail2rupok@gmail.com>`,
		subject: `Test email | ${process.env.APP_NAME}`,
		//text: "",
		html: `This is just a test email.`,
	}, function(error, info) {

		const webhook = new IncomingWebhook( process.env.SLACK_WEBHOOK_URL );
		let webhookText = '';

		if (error) {
			
			webhookText = `Email notification is not working.\n`;
			webhookText += JSON.stringify(error);
			console.log( error );
			
		} else {
			webhookText = 'Yes, email notification is working.';
		}

		webhook.send({ text: webhookText })
			.then(function(response) {
				res.send(webhookText);
			})
			.catch(function(error) { });
	});

});

module.exports = router;
