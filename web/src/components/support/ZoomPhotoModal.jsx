import React from 'react';
import { CloseIcon } from '../icons/index.js';

export const ZoomPhotoModal = ({ photoUrl, onClose }) => {
  if (!photoUrl) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        style={{
          maxWidth: '90vw',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ alignSelf: 'flex-end', marginBottom: '0.5rem' }}>
          <button
            type="button"
            onClick={onClose}
            className="btn btn-outline-sm"
            style={{ background: '#0f172a', display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
          >
            <CloseIcon size={14} /> Close Preview
          </button>
        </div>
        <img
          src={photoUrl}
          alt="High-resolution error inspector preview"
          style={{
            maxWidth: '100%',
            maxHeight: '80vh',
            borderRadius: '8px',
            border: '2px solid #38bdf8',
            boxShadow: '0 20px 40px rgba(0,0,0,0.8)',
          }}
        />
      </div>
    </div>
  );
};

export default ZoomPhotoModal;
