const express = require('express');
const router = express.Router();
const db = require('../dbConnection');
const validator = require('validator');

/**
 * Get result resource of last two years
 * @access: public
 */
router.get('/', function(req, res, next) {

    const sql = 'SELECT * FROM results WHERE pub_date >= DATE_SUB(NOW(), INTERVAL 2 YEAR) AND is_valid = 1 ORDER BY serial DESC;';

    db.query(
        sql,
        function (error, results, fields) {

            // catch sql error
            if (error) {
                res.status(500).send(error);
                return next;
            }

            let response = {
				data: results,
				total_count: results.length
            }
            
            res.status(200).send(response);
            return next;
        }
    );

});

/**
 * Get result resource of resultId
 * @access: public
 */
router.get('/:resultId', function(req, res, next) {

    const { resultId } = req.params;

    // validation
    if ( ! validator.isInt(resultId) ) {
        res.status(400).send({
            error: 'INVALID_INPUT',
            message: 'Result ID must be integer.'
        });
        return next;
    }

    const sql = 'SELECT serial, pub_date FROM results WHERE serial = ?;';
    
    db.query(
        sql, 
        [resultId], 
        function (error, results, fields) {

            // catch sql error
            if (error) {
                res.status(500).send(error);
                return next;
            }

            let response = {
                ...results[0]
            }

            res.status(200).send(response);
            return next;
        }
    );
  
});

/**
 * Get result numbers of resultId
 * @access: public
 */
router.get('/:resultId/numbers', function(req, res, next) {

    const { resultId } = req.params;

    // validation
    if ( ! validator.isInt(resultId) ) {
        res.status(400).send({
            error: 'INVALID_INPUT',
            message: 'Result ID must be integer.'
        });
        return next;
    }

    const sql = 'SELECT prizes.id as prize, value, number FROM result_numbers, prizes WHERE result_numbers.prize_id = prizes.id AND result_serial = ? ORDER BY prizes.id, number LIMIT 100';
    
    db.query(
        sql, 
        [resultId], 
        function (error, results, fields) {

            // catch sql error
            if (error) {
                res.status(500).send(error);
                return next;
            }

            const response = {
                data: results,
                total_count: results.length
            }

            res.status(200).send(response);
            return next;
        }
    );
  
});

/**
 * Check result of single number
 * @access: public
 */
router.get('/check/:number', function(req, res, next) {

    let { number } = req.params;

    // validation
    if ( ! validator.isInt(number) ) {
        res.status(400).send({
            error: 'INVALID_INPUT',
            message: 'Number must be integer.'
        });
        return next;
    }

    if ( ! validator.isInt(number, { min: 1, max: 9999999 }) ) {
		res.status(400).send({
			error: 'INVALID_INPUT_DATA',
			message: 'Value is out of range. Number should be between 1-9999999.'
		});
		return next;
	}

    number = validator.toInt(number);

    const sql = 'SELECT result_serial, prizes.id as prize, value, number FROM result_numbers, prizes WHERE result_numbers.prize_id = prizes.id AND number = ? LIMIT 1';
    
    db.query(
        sql, 
        [number], 
        function (error, results, fields) {

            // catch sql error
            if (error) {
                res.status(500).send(error);
                return next;
            }

            let response = {
                result: false,
                serial: null,
                prize: null,
                value: null,
                number: number
            };

            if ( results.length > 0 ) {
                response.result = true;
                response.serial = results[0].result_serial;
                response.prize = results[0].prize;
                response.value = results[0].value;
            }

            res.status(200).send(response);
            return next;
        }
    );  
});

module.exports = router;
