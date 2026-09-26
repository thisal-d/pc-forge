import React from 'react';
import { CloudIcon, CloudUploadIcon, AlertTriangleIcon, CheckIcon } from '../icons/index.js';

export const ProductImageUploader = ({
  idPrefix = 'add',
  imageUrl,
  blobPreview,
  isUploading,
  cloudinaryStatus,
  onFileChange,
  onUrlChange,
  onRemoveImage,
}) => {
  const isCloudinaryReady = cloudinaryStatus.isConfigured || imageUrl?.includes('cloudinary.com');

  return (
    <div className="form-group">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.4rem' }}>
        <label htmlFor={`${idPrefix}-product-image`} style={{ margin: 0, fontWeight: 600 }}>
          Product Image (Cloudinary)
        </label>
        {isCloudinaryReady ? (
          <span className="cloudinary-badge cloudinary-badge-success" title="Cloudinary is configured and ready on backend" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
            <CloudIcon size={14} /> Cloudinary Active ({cloudinaryStatus.cloudName || 'dsqbfupga'})
          </span>
        ) : (
          <span className="cloudinary-badge cloudinary-badge-warning" title={cloudinaryStatus.message || 'Configure Cloudinary in backend/.env'} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
            <AlertTriangleIcon size={14} /> Cloudinary Not Configured
          </span>
        )}
      </div>

      <div className="cloudinary-upload-container">
        {(imageUrl || blobPreview || isUploading) ? (
          <div className="cloudinary-preview-card">
            <div style={{ position: 'relative', width: '56px', height: '56px', flexShrink: 0 }}>
              <img
                src={imageUrl || blobPreview}
                alt="Preview"
                className="cloudinary-preview-img"
                onError={(e) => {
                  e.target.style.display = 'none';
                }}
              />
              {isUploading && (
                <div
                  style={{
                    position: 'absolute',
                    inset: 0,
                    background: 'rgba(0,0,0,0.5)',
                    borderRadius: 'var(--radius-sm)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#fff',
                  }}
                >
                  <span
                    className="spinner-border spinner-border-sm"
                    style={{
                      width: '18px',
                      height: '18px',
                      border: '2px solid #fff',
                      borderRightColor: 'transparent',
                      borderRadius: '50%',
                      display: 'inline-block',
                      animation: 'spin 0.75s linear infinite',
                    }}
                  ></span>
                </div>
              )}
            </div>

            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
                {isUploading ? (
                  <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#6366f1', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                    <CloudUploadIcon size={16} /> Uploading blob to Cloudinary...
                  </span>
                ) : imageUrl?.includes('cloudinary.com') ? (
                  <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#059669', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                    <CheckIcon size={14} /> Cloudinary CDN Asset
                  </span>
                ) : (
                  <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                    Image Attached
                  </span>
                )}
              </div>
              <p
                style={{
                  margin: '0.2rem 0 0 0',
                  fontSize: '0.75rem',
                  color: 'var(--text-muted)',
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {imageUrl || 'Streaming image blob to cloud...'}
              </p>
            </div>

            <div style={{ display: 'flex', gap: '0.4rem', flexShrink: 0 }}>
              <label
                htmlFor={`${idPrefix}-product-file-input`}
                className="btn btn-secondary"
                style={{ margin: 0, padding: '0.35rem 0.65rem', fontSize: '0.8rem', cursor: isUploading ? 'wait' : 'pointer' }}
              >
                Replace
              </label>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ margin: 0, padding: '0.35rem 0.65rem', fontSize: '0.8rem', color: '#ef4444' }}
                disabled={isUploading}
                onClick={onRemoveImage}
              >
                Remove
              </button>
            </div>
          </div>
        ) : (
          <label
            htmlFor={`${idPrefix}-product-file-input`}
            className="cloudinary-dropzone"
            onDragOver={(e) => {
              e.preventDefault();
              e.stopPropagation();
            }}
            onDrop={(e) => {
              e.preventDefault();
              e.stopPropagation();
              const file = e.dataTransfer.files?.[0];
              if (file) {
                onFileChange({ target: { files: [file], value: '' } });
              }
            }}
          >
            <div style={{ color: 'var(--primary)', marginBottom: '0.25rem' }}>
              <CloudUploadIcon size={32} />
            </div>
            <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>
              Click or drag & drop to upload image
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              JPEG, PNG, WebP, GIF (Max 5MB) • Streams image blob directly to Cloudinary
            </div>
          </label>
        )}

        <input
          id={`${idPrefix}-product-file-input`}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          style={{ display: 'none' }}
          disabled={isUploading}
          onChange={onFileChange}
        />

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.2rem' }}>
          <input
            id={`${idPrefix}-product-image`}
            name="imageUrl"
            type="url"
            placeholder="Or paste an existing Cloudinary image URL..."
            value={imageUrl}
            onChange={(e) => onUrlChange(e.target.value)}
            style={{ flex: 1, fontSize: '0.82rem', padding: '0.45rem 0.65rem' }}
          />
        </div>
      </div>
    </div>
  );
};

export default ProductImageUploader;
