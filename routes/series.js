const express = require('express');
const router = express.Router();
const db = require('../dbConnection');

/**
 * Get result resource of last two years
 * @access: public
 */
router.get('/', function(req, res, next) {

    const sql = 'SELECT * FROM series ORDER BY serial;';

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

module.exports = router;
