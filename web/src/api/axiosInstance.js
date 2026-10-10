import axios from 'axios';

const api = axios.create({
  baseURL: import.meta?.env?.VITE_API_BASE_URL || 'http://localhost:5000/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor: Attach JWT token from localStorage to Authorization header
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('pcforge_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    // For multipart FormData uploads, remove default application/json so browser sets boundary
    if (typeof FormData !== 'undefined' && config.data instanceof FormData) {
      delete config.headers['Content-Type'];
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor: Handle 401 Unauthorized globally
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      // Clear token on 401
      localStorage.removeItem('pcforge_token');
      localStorage.removeItem('pcforge_user');
    }
    return Promise.reject(error);
  }
);

export default api;
