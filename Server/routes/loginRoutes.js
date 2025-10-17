const express = require('express');
const router = express.Router();
const loginServices = require('../services/loginServices');

router.post('/', async (req, res) => {
  try {
    const { phone_number, password, platform } = req.body;
    console.log(`Login attempt for phone_number: ${phone_number}`);
    const result = await loginServices.login(phone_number, password, platform);
    console.log('Login result:', result);
    if (result.success) {
      res.status(200).json({ token: result.token, message: 'Login successful' });
    } else {
      res.status(401).json({ message: result.message });
    }
  } catch (error) {
    console.error('Login route error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

module.exports = router;
