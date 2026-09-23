import api from '../api/axiosInstance.js';

/**
 * Service to handle image uploads strictly to Cloudinary via the backend API,
 * plus local Blob creation for instant UI previews.
 */
export const uploadService = {
  /**
   * Uploads an image File or Blob to Cloudinary via the backend.
   * @param {File|Blob} file - The image file or blob to upload
   * @returns {Promise<{ url: string, publicId?: string, fileName?: string, storageProvider: string }>}
   */
  async uploadImage(file) {
    if (!file) {
      throw new Error('No image file was provided for upload.');
    }

    // Validate size (max 5MB)
    const MAX_SIZE_MB = 5;
    if (file.size > MAX_SIZE_MB * 1024 * 1024) {
      throw new Error(`Image size exceeds the ${MAX_SIZE_MB}MB limit (actual: ${(file.size / 1024 / 1024).toFixed(2)}MB).`);
    }

    // Validate mime type
    const validTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (file.type && !validTypes.includes(file.type)) {
      throw new Error('Unsupported image format. Allowed formats: JPEG, PNG, WebP, GIF.');
    }

    const formData = new FormData();
    formData.append('file', file, file.name || 'product-image.webp');

    try {
      const response = await api.post('/upload/image', formData, {
        headers: {
          'Content-Type': undefined,
        },
      });

      const data = response.data;
      if (!data || !data.url) {
        throw new Error('Cloudinary upload completed but returned an invalid URL response.');
      }

      return {
        url: data.url,
        publicId: data.publicId,
        fileName: data.fileName || file.name,
        storageProvider: data.storageProvider || 'Cloudinary',
      };
    } catch (error) {
      if (!error.response) {
        throw new Error(
          'Backend API is unreachable. Please ensure the backend server is running (http://localhost:5000) to upload images to Cloudinary.'
        );
      }

      if (error.response.status === 401) {
        throw new Error('Your session has expired or you are not logged in. Please log in again to upload product images.');
      }

      const errorsObj = error.response.data?.errors;
      const validationMsg = errorsObj ? Object.values(errorsObj).flat().join(' ') : null;
      const backendMessage = error.response.data?.message || validationMsg || error.response.data?.title || error.message;
      throw new Error(backendMessage || 'Failed to upload image to Cloudinary.');
    }
  },

  /**
   * Checks whether Cloudinary is configured and ready on the backend.
   * @returns {Promise<{ isConfigured: boolean, cloudName?: string, provider: string, message: string }>}
   */
  async getCloudinaryStatus() {
    try {
      const response = await api.get('/upload/status');
      return response.data;
    } catch {
      return {
        isConfigured: false,
        cloudName: null,
        provider: 'Cloudinary',
        message: 'Could not connect to backend upload status endpoint.',
      };
    }
  },

  /**
   * Creates a local Blob URL for immediate instant UI preview before/during upload.
   * Note: This is an ephemeral client-side URL and MUST NOT be saved to the database.
   * @param {File|Blob} file
   * @returns {string}
   */
  createBlobPreview(file) {
    if (!file) return '';
    return URL.createObjectURL(file);
  },

  /**
   * Revokes an ephemeral blob preview URL to avoid browser memory leaks.
   * @param {string} blobUrl
   */
  revokeBlobPreview(blobUrl) {
    if (blobUrl && typeof blobUrl === 'string' && blobUrl.startsWith('blob:')) {
      try {
        URL.revokeObjectURL(blobUrl);
      } catch {
        // ignore
      }
    }
  },
};

export default uploadService;
