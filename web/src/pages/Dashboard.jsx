import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export const Dashboard = () => {
  const { user, role } = useAuth();

  return (
    <div className="page-container">
      <div className="dashboard-header">
        <div>
          <h1>User Dashboard</h1>
          <p className="subtitle">
            Welcome back, <strong>{user?.firstName || 'User'} {user?.lastName || ''}</strong>
          </p>
        </div>
        <span className={`badge badge-lg badge-${role?.toLowerCase()}`}>
          Role: {role}
        </span>
      </div>

      <div className="grid grid-2">
        <div className="card">
          <h3>Authentication Details</h3>
          <table className="info-table">
            <tbody>
              <tr>
                <td><strong>User ID:</strong></td>
                <td>{user?.userId}</td>
              </tr>
              <tr>
                <td><strong>Email:</strong></td>
                <td>{user?.email}</td>
              </tr>
              <tr>
                <td><strong>Role Claim:</strong></td>
                <td><span className={`badge badge-${role?.toLowerCase()}`}>{role}</span></td>
              </tr>
              <tr>
                <td><strong>Token Type:</strong></td>
                <td>Stateless Bearer JWT</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3>Role-Based Access Control</h3>
          <p>Your current role determines which routes and API resources you can access:</p>
          <ul className="permission-list">
            <li>
              <span>Global Catalog & Orders</span>
              <span className="badge badge-success">Allowed (All Roles)</span>
            </li>
            <li>
              <span>Store Inventory & Products (<code>/inventory</code>)</span>
              {role === 'Admin' || role === 'Staff' ? (
                <span className="badge badge-success">Authorized</span>
              ) : (
                <span className="badge badge-error">Staff / Admin Only</span>
              )}
            </li>
            <li>
              <span>AI Build Validation & Overrides</span>
              {role === 'Admin' || role === 'Staff' ? (
                <span className="badge badge-success">Authorized</span>
              ) : (
                <span className="badge badge-error">Staff / Admin Only</span>
              )}
            </li>
            <li>
              <span>Order Fulfillment & Status Updates</span>
              {role === 'Admin' || role === 'Staff' ? (
                <span className="badge badge-success">Authorized</span>
              ) : (
                <span className="badge badge-error">Staff / Admin Only</span>
              )}
            </li>
            <li>
              <span>After-Sales Service Requests</span>
              {role === 'Admin' || role === 'Staff' ? (
                <span className="badge badge-success">Authorized</span>
              ) : (
                <span className="badge badge-error">Staff / Admin Only</span>
              )}
            </li>
            <li>
              <span>Product Catalog Management (<code>/products</code>)</span>
              {role === 'Admin' || role === 'Staff' ? (
                <span className="badge badge-success">Authorized</span>
              ) : (
                <span className="badge badge-error">Staff / Admin Only</span>
              )}
            </li>
            <li>
              <span>Category & Filter Configuration (<code>/categories</code>)</span>
              {role === 'Admin' || role === 'Staff' ? (
                <span className="badge badge-success">Authorized</span>
              ) : (
                <span className="badge badge-error">Staff / Admin Only</span>
              )}
            </li>
            <li>
              <span>Staff Account Administration (<code>/staff</code>)</span>
              {role === 'Admin' ? (
                <span className="badge badge-success">Authorized (Admin Only)</span>
              ) : (
                <span className="badge badge-error">Restricted: Admin Only</span>
              )}
            </li>
          </ul>

          <div style={{ marginTop: '1.5rem', display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
            {(role === 'Admin' || role === 'Staff') && (
              <>
                <Link to="/inventory" className="btn btn-outline" id="dashboard-inventory-link">
                  Go to /inventory
                </Link>
                <Link to="/build-reviews" className="btn btn-outline" id="dashboard-build-reviews-link">
                  Build Reviews Queue →
                </Link>
                <Link to="/support" className="btn btn-outline" id="dashboard-support-link">
                  Service Requests Workbench →
                </Link>
              </>
            )}
            {role === 'Admin' && (
              <>
                <Link to="/staff" className="btn btn-outline" id="dashboard-staff-link">
                  Staff Management
                </Link>
                <Link to="/categories" className="btn btn-primary" id="dashboard-categories-link">
                  Category Management →
                </Link>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
