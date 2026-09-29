import React, { useState, useRef, useEffect } from 'react';
import { NavLink, Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export const Navbar = () => {
  const { user, isAuthenticated, role, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef(null);

  const roleNormalized = (role || '').trim().toLowerCase();
  const isStaffOrAdmin = roleNormalized === 'admin' || roleNormalized === 'staff';
  const isAdmin = roleNormalized === 'admin';

  const handleLogout = () => {
    setIsDropdownOpen(false);
    logout();
    navigate('/login');
  };

  // Close user dropdown on outside click
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const getInitials = () => {
    if (user?.firstName && user?.lastName) {
      return `${user.firstName[0]}${user.lastName[0]}`.toUpperCase();
    }
    if (role === 'Admin') return 'AD';
    if (role === 'Staff') return 'ST';
    return (user?.email?.slice(0, 2) || 'US').toUpperCase();
  };

  const getUserDisplayName = () => {
    if (user?.firstName) {
      return `${user.firstName} ${user.lastName || ''}`.trim();
    }
    return role || 'User';
  };

  const topNavTabs = [
    {
      to: '/dashboard',
      label: 'Dashboard',
      icon: (
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>
        </svg>
      ),
    },
    ...(isStaffOrAdmin
      ? [
          {
            to: '/inventory',
            label: 'Inventory',
            id: 'nav-inventory-link',
            icon: (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
                <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
                <line x1="12" y1="22.08" x2="12" y2="12"></line>
              </svg>
            ),
          },
          {
            to: '/build-reviews',
            label: 'Build Reviews',
            id: 'nav-build-reviews-link',
            icon: (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                <polyline points="14 2 14 8 20 8"></polyline>
                <line x1="16" y1="13" x2="8" y2="13"></line>
              </svg>
            ),
          },
          {
            to: '/support',
            label: 'Support Tickets',
            id: 'nav-support-link',
            icon: (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
              </svg>
            ),
          },
          {
            to: '/products',
            label: 'Products',
            id: 'nav-products-link',
            icon: (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="2" y="7" width="20" height="14" rx="2" ry="2"></rect>
              </svg>
            ),
          },
          {
            to: '/categories',
            label: 'Categories',
            id: 'nav-categories-link',
            icon: (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>
              </svg>
            ),
          },
        ]
      : []),
    ...(isAdmin
      ? [
          {
            to: '/staff',
            label: 'Staff Management',
            id: 'nav-staff-link',
            icon: (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
              </svg>
            ),
          },
        ]
      : []),
  ];

  return (
    <header className="top-navbar">
      <div className="top-navbar-container">
        {/* Left: Brand Logo */}
        <Link to="/" className="top-navbar-brand">
          <div className="brand-logo-box">
            <img src="/logo.png" alt="PCForge Logo" className="brand-logo-img" />
          </div>
          <span className="brand-title">PCForge</span>
        </Link>

        {/* Center: Top Horizontal Navigation Tabs */}
        {isAuthenticated && (
          <nav className="top-navbar-tabs">
            {topNavTabs.map((tab) => {
              const isActive = location.pathname === tab.to;
              return (
                <NavLink
                  key={tab.to}
                  to={tab.to}
                  id={tab.id}
                  className={`top-nav-tab ${isActive ? 'active' : ''}`}
                >
                  <span className="top-nav-tab-icon">{tab.icon}</span>
                  <span>{tab.label}</span>
                </NavLink>
              );
            })}
          </nav>
        )}

        {/* Right: Actions (Notification & User Profile) */}
        <div className="top-navbar-right">
          {isAuthenticated ? (
            <>
              {/* Notification Bell */}
              <button className="top-nav-icon-btn" title="Notifications" type="button">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
                  <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
                </svg>
                <span className="notification-badge-dot"></span>
              </button>

              {/* User Profile Pill & Dropdown */}
              <div className="user-profile-wrapper" ref={dropdownRef}>
                <button
                  type="button"
                  className="user-profile-btn"
                  onClick={() => setIsDropdownOpen((prev) => !prev)}
                  aria-expanded={isDropdownOpen}
                >
                  <div className="user-avatar-circle">{getInitials()}</div>
                  <span className="user-profile-name">{getUserDisplayName()}</span>
                  <svg
                    className={`user-chevron ${isDropdownOpen ? 'open' : ''}`}
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <polyline points="6 9 12 15 18 9"></polyline>
                  </svg>
                </button>

                {isDropdownOpen && (
                  <div className="user-dropdown-menu">
                    <div className="user-dropdown-header">
                      <div className="user-dropdown-email">{user?.email}</div>
                      <span className={`badge badge-sm badge-${role?.toLowerCase()}`}>
                        {role}
                      </span>
                    </div>
                    <div className="user-dropdown-divider"></div>
                    <Link
                      to="/dashboard"
                      className="user-dropdown-item"
                      onClick={() => setIsDropdownOpen(false)}
                    >
                      Dashboard Overview
                    </Link>
                    <button
                      type="button"
                      className="user-dropdown-item user-dropdown-logout"
                      onClick={handleLogout}
                    >
                      Sign Out
                    </button>
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="auth-buttons-group">
              <Link to="/login" className="btn btn-outline-sm">
                Login
              </Link>
              <Link to="/register" className="btn btn-primary-sm">
                Register
              </Link>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

export default Navbar;
