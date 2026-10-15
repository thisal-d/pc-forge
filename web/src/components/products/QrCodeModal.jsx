import React, { useState, useEffect } from 'react';
import QRCode from 'qrcode';
import { CloseIcon, QrCodeIcon, CheckIcon, InfoIcon } from '../icons/index.js';

export const QrCodeModal = ({ product, isOpen, onClose }) => {
  const [qrDataUrl, setQrDataUrl] = useState('');
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState(null);

  const prodId = product?.productId || product?.id;
  // Exact identifier payload expected by the existing Flutter mobile scanner
  const qrIdentifier = prodId
    ? JSON.stringify({ productId: Number(prodId), name: product?.name || '' })
    : '';

  useEffect(() => {
    if (!isOpen || !product || !prodId) {
      setQrDataUrl('');
      setError(null);
      return;
    }

    let isMounted = true;
    QRCode.toDataURL(qrIdentifier, {
      width: 240,
      margin: 2,
      errorCorrectionLevel: 'M',
      color: {
        dark: '#0f172a',
        light: '#ffffff',
      },
    })
      .then((url) => {
        if (isMounted) {
          setQrDataUrl(url);
          setError(null);
        }
      })
      .catch((err) => {
        if (isMounted) {
          console.error('Failed to generate QR code:', err);
          setError('Failed to generate QR code.');
        }
      });

    return () => {
      isMounted = false;
    };
  }, [isOpen, product, prodId, qrIdentifier]);

  if (!isOpen || !product) return null;

  const handleCopyIdentifier = () => {
    if (!qrIdentifier) return;
    navigator.clipboard?.writeText(qrIdentifier).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    });
  };

  return (
    <div className="modal-backdrop" onClick={onClose} id="qr-code-modal-backdrop">
      <div
        className="modal-dialog"
        style={{ maxWidth: '440px', textAlign: 'center' }}
        onClick={(e) => e.stopPropagation()}
        id={`qr-modal-${prodId}`}
      >
        {/* Header */}
        <div className="modal-header" style={{ alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
            <div
              style={{
                width: '32px',
                height: '32px',
                borderRadius: '8px',
                background: 'var(--primary-light, #eff6ff)',
                color: 'var(--primary, #2563eb)',
                border: '1px solid var(--primary-border, #bfdbfe)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <QrCodeIcon size={18} />
            </div>
            <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: 'var(--text-main, #0f172a)' }}>
              Product QR Code
            </h3>
          </div>
          <button onClick={onClose} className="modal-close-btn" title="Close modal" id="close-qr-modal-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        {/* Body */}
        <div className="modal-body" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          {/* Product Header */}
          <div style={{ marginBottom: '1.25rem', width: '100%' }}>
            <span
              className="id-badge"
              style={{
                fontSize: '0.8rem',
                padding: '2px 8px',
                marginBottom: '0.4rem',
                display: 'inline-block',
              }}
            >
              PRD-{String(prodId).padStart(2, '0')}
            </span>
            <h4
              style={{
                margin: '0.35rem 0',
                color: 'var(--text-main, #0f172a)',
                fontSize: '1.15rem',
                fontWeight: 700,
                lineHeight: 1.35,
              }}
            >
              {product.name}
            </h4>
            <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', alignItems: 'center', marginTop: '0.35rem' }}>
              <span className="cat-pill cat-badge-default" style={{ fontSize: '0.75rem' }}>
                {product.categoryName || 'Component'}
              </span>
              {product.brand && (
                <span style={{ fontSize: '0.8rem', color: 'var(--text-muted, #64748b)' }}>
                  Brand: <strong style={{ color: 'var(--text-body, #334155)' }}>{product.brand}</strong>
                </span>
              )}
              {product.price && (
                <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--primary, #2563eb)' }}>
                  • LKR {Number(product.price).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </span>
              )}
            </div>
          </div>

          {/* QR Code Canvas / Image Display */}
          <div
            style={{
              padding: '1.15rem',
              background: '#ffffff',
              borderRadius: 'var(--radius-lg, 12px)',
              border: '1px solid var(--border, #e2e8f0)',
              boxShadow: 'var(--shadow-md, 0 4px 6px -1px rgba(0, 0, 0, 0.07))',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minWidth: '220px',
              minHeight: '220px',
            }}
          >
            {error ? (
              <span style={{ color: 'var(--danger-text, #dc2626)', fontSize: '0.85rem' }}>{error}</span>
            ) : qrDataUrl ? (
              <img
                src={qrDataUrl}
                alt={`QR code for ${product.name}`}
                style={{ width: '220px', height: '220px', display: 'block', borderRadius: '4px' }}
                id={`qr-image-${prodId}`}
              />
            ) : (
              <span style={{ color: 'var(--text-muted, #64748b)', fontSize: '0.85rem' }}>Generating QR Code...</span>
            )}
          </div>

          {/* Scanner Guidance */}
          <div
            style={{
              marginTop: '1.25rem',
              padding: '0.85rem 1rem',
              background: 'var(--primary-light, #eff6ff)',
              borderRadius: 'var(--radius-md, 8px)',
              border: '1px solid var(--primary-border, #bfdbfe)',
              width: '100%',
              textAlign: 'left',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', marginBottom: '0.25rem' }}>
              <span style={{ color: 'var(--primary, #2563eb)', display: 'inline-flex' }}>
                <InfoIcon size={14} />
              </span>
              <strong style={{ fontSize: '0.8rem', color: 'var(--primary, #1d4ed8)', fontWeight: 700 }}>
                Mobile Scanner Verification
              </strong>
            </div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-body, #334155)', lineHeight: 1.45, marginBottom: '0.65rem' }}>
              Scan this code in the PCForge Mobile App to verify hardware specifications, live stock, and compatibility.
            </div>

            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0.35rem 0.65rem',
                background: '#ffffff',
                border: '1px solid var(--primary-border, #bfdbfe)',
                borderRadius: 'var(--radius-sm, 6px)',
                fontFamily: 'monospace',
                fontSize: '0.75rem',
              }}
            >
              <span style={{ color: 'var(--primary, #2563eb)', fontWeight: 600 }}>PROD-{prodId}</span>
              <button
                type="button"
                onClick={handleCopyIdentifier}
                style={{
                  background: copied ? 'var(--success-light, #ecfdf5)' : 'var(--primary-light, #eff6ff)',
                  border: `1px solid ${copied ? 'var(--success-border, #a7f3d0)' : 'var(--primary-border, #bfdbfe)'}`,
                  color: copied ? 'var(--success-text, #059669)' : 'var(--primary, #2563eb)',
                  cursor: 'pointer',
                  fontSize: '0.72rem',
                  fontWeight: 600,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '4px',
                  padding: '3px 8px',
                  borderRadius: '4px',
                  transition: 'all 0.15s ease',
                }}
                title="Copy raw identifier payload"
              >
                {copied ? (
                  <>
                    <CheckIcon size={12} />
                    <span>Copied!</span>
                  </>
                ) : (
                  <span>Copy Payload</span>
                )}
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="modal-footer" style={{ justifyContent: 'center' }}>
          <button
            type="button"
            onClick={onClose}
            className="btn btn-primary-sm"
            style={{ minWidth: '110px', padding: '0.45rem 1.25rem', fontWeight: 600 }}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default QrCodeModal;
