import axios from 'axios';
import { SERVER_IP } from '../constant';



export async function login(phone_number, password, platform) {
  try {
    
    const response = await axios.post(
      `http://${SERVER_IP}:5000/api/login`,
      { phone_number, password, platform }
    );
    return { success: true, token: response.data.token, message: response.data.message };
  } catch (error) {
    if (error.response) {
      // Backend error response
      return { success: false, message: error.response.data.message };
    } else {
      // Network/server error
      return { success: false, message: 'Login failed, server error.' };
    }
  }
}
