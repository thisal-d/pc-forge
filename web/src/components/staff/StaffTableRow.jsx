import React from 'react';
import { StarIcon } from '../icons/index.js';

const getInitials = (firstName, lastName) => {
  const f = firstName ? firstName[0].toUpperCase() : '';
  const l = lastName ? lastName[0].toUpperCase() : '';
  return `${f}${l}` || 'ST';
};

export const StaffTableRow = ({
  member,
  onView,
  onEdit,
  onResetPassword,
  onToggleStatus,
  onDelete,
}) => {
  const isActive = member.status === 'Active';

  return (
    <tr id={`staff-row-${member.id}`}>
      {/* User Cell */}
      <td>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div className="user-avatar" style={{ width: '36px', height: '36px', fontSize: '0.85rem' }}>
            {getInitials(member.firstName, member.lastName)}
          </div>
          <div>
            <div style={{ fontWeight: 600, color: 'var(--text-main)', fontSize: '0.9rem' }}>
              {member.firstName} {member.lastName}
            </div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
              {member.email}
            </div>
          </div>
        </div>
      </td>

      {/* Staff ID */}
      <td>
        <span className="id-badge">{member.id}</span>
      </td>

      {/* Department & Specialization */}
      <td>
        <div style={{ fontSize: '0.85rem', color: 'var(--text-main)' }}>
          {member.department}
        </div>
        {member.specialization && (
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.15rem' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
              <StarIcon size={12} color="#fbbf24" fill="#fbbf24" /> {member.specialization}
            </span>
          </div>
        )}
      </td>

      {/* Phone */}
      <td style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
        {member.phone || '—'}
      </td>

      {/* Status */}
      <td>
        <span className={`badge ${isActive ? 'badge-success' : 'badge-warning'}`}>
          {member.status}
        </span>
      </td>

      {/* Joined Date */}
      <td style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
        {member.createdDate || member.joinedDate || '—'}
      </td>

      {/* Actions */}
      <td>
        <div className="action-btn-group" style={{ justifyContent: 'flex-end' }}>
          <button
            type="button"
            onClick={() => onView(member)}
            className="btn btn-outline-sm"
            title="View complete staff file"
            id={`view-staff-btn-${member.id}`}
          >
            View
          </button>
          <button
            type="button"
            onClick={() => onEdit(member)}
            className="btn btn-outline-sm"
            title="Edit staff details"
            id={`edit-staff-btn-${member.id}`}
          >
            Edit
          </button>
          <button
            type="button"
            onClick={() => onResetPassword(member)}
            className="btn btn-outline-sm"
            title="Reset staff password"
            id={`reset-pwd-btn-${member.id}`}
          >
            Reset Pwd
          </button>
          <button
            type="button"
            onClick={() => onToggleStatus(member)}
            className={isActive ? 'btn-warning-sm' : 'btn-success-sm'}
            title={isActive ? 'Deactivate staff account' : 'Activate staff account'}
            id={`toggle-status-btn-${member.id}`}
          >
            {isActive ? 'Deactivate' : 'Activate'}
          </button>
          <button
            type="button"
            onClick={() => onDelete(member)}
            className="btn-danger-sm"
            title="Delete staff account"
            id={`delete-staff-btn-${member.id}`}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  );
};

export default StaffTableRow;
