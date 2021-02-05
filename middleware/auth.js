const jwt = require('jsonwebtoken');
const dotenv = require('dotenv');
dotenv.config();

const secret = process.env.TOKEN_SECRET;

const auth = async(req, res, next) => {

    try {

        const token = req.header('Authorization').replace('Bearer ', '');
        const userData = jwt.verify(token, secret);

        //ToDo: maybe varify if user exists

        req.id = userData.id;
        req.uid = userData.uid;
        req.email = userData.email;
        req.role = userData.role;

        next();

    } catch (error) {

        res.status(401).send({ 
            error: 'UNAUTHORIZED_ACCESS',
            message: 'Not authorized to access this resource.'
        });

    }

}

module.exports = auth;
