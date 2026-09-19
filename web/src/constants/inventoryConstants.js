export const ADJUSTMENT_REASONS = [
  { value: 'Shipment Received', label: 'Shipment Received (Supplier delivery)' },
  { value: 'Inventory Audit', label: 'Inventory Audit (Physical count discrepancy)' },
  { value: 'Damaged Stock', label: 'Damaged Stock (Write-off)' },
  { value: 'Customer Return', label: 'Customer Return (Restocked to shelf)' },
  { value: 'Correction', label: 'Manual Correction' },
];

export const getCategoryBadgeClass = (categoryName) => {
  switch ((categoryName || '').toUpperCase()) {
    case 'GPU':
      return 'cat-badge-gpu';
    case 'CPU':
      return 'cat-badge-cpu';
    case 'MOTHERBOARD':
      return 'cat-badge-motherboard';
    case 'PSU':
      return 'cat-badge-psu';
    case 'RAM':
      return 'cat-badge-ram';
    default:
      return 'cat-badge-default';
  }
};

export const getStockPercentage = (stock) => {
  const maxTarget = 15;
  return Math.min(100, Math.round((stock / maxTarget) * 100));
};
