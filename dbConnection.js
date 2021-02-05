const mysql = require('mysql');
const dotenv = require('dotenv');
dotenv.config();

/*
const db = mysql.createConnection({
	host     : process.env.DB_HOST,
	port     : process.env.DB_PORT,
	user     : process.env.DB_USER,
	password : process.env.DB_PASSWORD,
	database : process.env.DB_NAME,
	multipleStatements: true
});
*/

const db = mysql.createPool({
	connectionLimit : 10,
	host     : process.env.DB_HOST,
	port     : process.env.DB_PORT,
	user     : process.env.DB_USER,
	password : process.env.DB_PASSWORD,
	database : process.env.DB_NAME,
	multipleStatements: true
});

module.exports = db;