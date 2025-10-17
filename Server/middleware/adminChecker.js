const pool = require("../db/database");

const adminChecker = async (req, res, next) => {
    try {
        const user_id = req.user_id;
        const adminCheck = await pool.query("SELECT category_id FROM user_details WHERE user_id = $1", [user_id]);
        if (adminCheck.rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        if (adminCheck.rows[0].category_id !== 3) {
            return res.status(403).json({ message: 'Access denied, Admins only' });
        }
        next();
    } catch (error) {
        console.error('Error checking admin status:', error);
        res.status(500).json({ message: 'Internal server error' });
    }
}

module.exports = adminChecker;
            

