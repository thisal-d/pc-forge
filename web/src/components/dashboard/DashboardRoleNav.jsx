import React from 'react';
import { Link } from 'react-router-dom';
import {
  ToolsIcon,
  WrenchIcon,
  PackageIcon,
  UsersIcon,
  SettingsIcon,
  ShieldCheckIcon,
  TagIcon,
  MonitorIcon,
} from '../icons/index.js';

export const DashboardRoleNav = ({ role = 'Staff', perspective = 'all', onSelectPerspective }) => {
  const roleNorm = (role || '').trim().toLowerCase();
  const isAdmin = roleNorm === 'admin';
  const isStaff = roleNorm === 'staff' || isAdmin;

  const quickNavLinks = [
    {
      to: '/orders',
      title: 'Orders Pipeline',
      desc: 'Track customer orders, manage fulfillment stages & dispatch.',
      icon: <PackageIcon size={20} />,
      badge: 'Staff / Admin',
      badgeClass: 'badge-success',
      allowed: isStaff,
      id: 'quick-nav-orders',
    },
    {
      to: '/build-reviews',
      title: 'Custom Build Reviews',
      desc: 'Inspect PC compatibility, power headroom & technical clearance.',
      icon: <ToolsIcon size={20} />,
      badge: 'Technician',
      badgeClass: 'badge-info',
      allowed: isStaff,
      id: 'quick-nav-builds',
    },
    {
      to: '/service-requests',
      title: 'Service Requests',
      desc: 'Triage hardware diagnostics, schedule slots & assign tickets.',
      icon: <WrenchIcon size={20} />,
      badge: 'Technician',
      badgeClass: 'badge-purple',
      allowed: isStaff,
      id: 'quick-nav-services',
    },
    {
      to: '/inventory',
      title: 'Warehouse & Inventory',
      desc: 'Real-time stock tracking, replenishment thresholds & adjustments.',
      icon: <MonitorIcon size={20} />,
      badge: 'Inventory',
      badgeClass: 'badge-warning',
      allowed: isStaff,
      id: 'quick-nav-inventory',
    },
    {
      to: '/products',
      title: 'Product Catalog',
      desc: 'Manage hardware components, specifications, pricing & models.',
      icon: <TagIcon size={20} />,
      badge: 'Staff / Admin',
      badgeClass: 'badge-neutral',
      allowed: isStaff,
      id: 'quick-nav-products',
    },
    {
      to: '/staff',
      title: 'Staff Management',
      desc: 'Provision staff accounts, roles, departments & credentials.',
      icon: <UsersIcon size={20} />,
      badge: 'Admin Only',
      badgeClass: 'badge-error',
      allowed: isAdmin, // Strictly enforced: ONLY Admin can access
      id: 'quick-nav-staff',
    },
    {
      to: '/categories',
      title: 'Categories & Taxonomy',
      desc: 'Configure component classifications and compatibility rules.',
      icon: <SettingsIcon size={20} />,
      badge: 'Admin / Staff',
      badgeClass: 'badge-neutral',
      allowed: isStaff,
      id: 'quick-nav-categories',
    },
  ];

  const filteredLinks = quickNavLinks.filter((item) => item.allowed);

  return (
    <div className="dashboard-role-nav-section" id="role-navigation-section">
      <div className="section-header-row">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h2 className="section-title">Role-Based Operations & Quick Navigation</h2>
            <span className={`badge badge-lg ${isAdmin ? 'badge-error' : 'badge-info'}`}>
              <ShieldCheckIcon size={14} style={{ marginRight: '4px' }} />
              {isAdmin ? 'Administrator Scope' : 'Staff Scope'}
            </span>
          </div>
          <p className="section-subtitle">
            Direct access to modules authorized for your credential level according to ASP.NET Core security policies.
          </p>
        </div>

        {/* Perspective Switcher for Admin or Staff */}
        {onSelectPerspective && (
          <div className="perspective-selector">
            <span className="selector-label">Focus View:</span>
            <div className="btn-group-pill">
              <button
                type="button"
                className={`pill-btn ${perspective === 'all' ? 'active' : ''}`}
                onClick={() => onSelectPerspective('all')}
              >
                All Operations
              </button>
              <button
                type="button"
                className={`pill-btn ${perspective === 'technician' ? 'active' : ''}`}
                onClick={() => onSelectPerspective('technician')}
              >
                Technician
              </button>
              <button
                type="button"
                className={`pill-btn ${perspective === 'inventory' ? 'active' : ''}`}
                onClick={() => onSelectPerspective('inventory')}
              >
                Inventory
              </button>
            </div>
          </div>
        )}
      </div>

      <div className="role-nav-grid">
        {filteredLinks.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            className="role-nav-card"
            id={item.id}
          >
            <div className="role-nav-top">
              <div className="role-nav-icon-box">{item.icon}</div>
              <span className={`badge ${item.badgeClass}`} style={{ fontSize: '0.7rem' }}>
                {item.badge}
              </span>
            </div>
            <h4 className="role-nav-title">{item.title}</h4>
            <p className="role-nav-desc">{item.desc}</p>
            <div className="role-nav-footer">
              <span>Launch module &rarr;</span>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
};

export default DashboardRoleNav;
