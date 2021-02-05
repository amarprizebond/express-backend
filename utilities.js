const jwt = require('jsonwebtoken');
const dotenv = require('dotenv');
dotenv.config();

const secret = process.env.TOKEN_SECRET;

module.exports = {

    generateToken(user) {
        let token = jwt.sign({
            id: user.id,
            uid: user.uid,
            email: user.email,
            role: user.role
        }, secret, { expiresIn: '1d' });

        return `Bearer ${token}`;
    }
}
