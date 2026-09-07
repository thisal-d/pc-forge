import api from '../api/axiosInstance';

const TOKEN_KEY = 'pcforge_token';
const USER_KEY = 'pcforge_user';

export const authService = {
  // Login user and store token
  async login(email, password) {
    const response = await api.post('/auth/login', { email, password });
    if (response.data && response.data.token) {
      localStorage.setItem(TOKEN_KEY, response.data.token);
      localStorage.setItem(USER_KEY, JSON.stringify({
        userId: response.data.userId,
        email: response.data.email,
        role: response.data.role,
        firstName: response.data.firstName,
        lastName: response.data.lastName,
      }));
    }
    return response.data;
  },

  // Register user and store token
  async register({ email, password, role, firstName, lastName }) {
    const response = await api.post('/auth/register', {
      email,
      password,
      role,
      firstName,
      lastName,
    });
    if (response.data && response.data.token) {
      localStorage.setItem(TOKEN_KEY, response.data.token);
      localStorage.setItem(USER_KEY, JSON.stringify({
        userId: response.data.userId,
        email: response.data.email,
        role: response.data.role,
        firstName: response.data.firstName,
        lastName: response.data.lastName,
      }));
    }
    return response.data;
  },

  // Logout user and clear local storage
  logout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  },

};
