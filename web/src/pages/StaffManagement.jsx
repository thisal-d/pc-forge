import React, { useState, useMemo, useEffect } from 'react';
import { staffService } from '../services/staffService';
import {
  StaffStats,
  StaffToolbar,
  StaffTable,
  StaffFormModal,
  ResetPasswordModal,
  ViewStaffModal,
  DeleteStaffModal,
} from '../components/staff';
import { CloseIcon } from '../components/icons';

export const StaffManagement = () => {
  // Master raw staff list state
  const [rawStaffList, setRawStaffList] = useState([]);
  const [loading, setLoading] = useState(true);

  // Automatically fetch live staff list from PostgreSQL backend API on mount
  useEffect(() => {
    let isMounted = true;
    setLoading(true);
    staffService
      .fetchStaffFromApi()
      .then((list) => {
        if (isMounted && Array.isArray(list)) {
          setRawStaffList(list);
        }
      })
      .finally(() => {
        if (isMounted) setLoading(false);
      });
    return () => {
      isMounted = false;
    };
  }, []);

  // Filter & Search states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [departmentFilter, setDepartmentFilter] = useState('all');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Notification state
  const [notification, setNotification] = useState(null);

  // Add / Edit Modal states
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState('add'); // 'add' | 'edit'
  const [currentStaffId, setCurrentStaffId] = useState(null);
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    phone: '+94 ',
    department: 'Hardware Diagnostics & Repair',
    specialization: '',
    status: 'Active',
    password: '',
    confirmPassword: '',
    notes: '',
  });
  const [formErrors, setFormErrors] = useState({});
  const [formGeneralError, setFormGeneralError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Reset Password Modal states
  const [isResetModalOpen, setIsResetModalOpen] = useState(false);
  const [resetCandidate, setResetCandidate] = useState(null);
  const [resetPasswordData, setResetPasswordData] = useState({ password: '', confirmPassword: '' });
  const [resetErrors, setResetErrors] = useState({});
  const [resetGeneralError, setResetGeneralError] = useState('');
  const [resetSubmitting, setResetSubmitting] = useState(false);

  // Staff Details (View) Modal state
  const [viewingStaff, setViewingStaff] = useState(null);

  // Delete Confirmation Modal state
  const [deleteCandidate, setDeleteCandidate] = useState(null);

  // Reset pagination on filter or search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, statusFilter, departmentFilter]);

  // Derived filtered staff list
  const staffList = useMemo(() => {
    return staffService.filterStaff(rawStaffList, {
      search: searchQuery,
      status: statusFilter,
    }).filter((m) => {
      if (departmentFilter !== 'all' && (m.department || '') !== departmentFilter) {
        return false;
      }
      return true;
    });
  }, [rawStaffList, searchQuery, statusFilter, departmentFilter]);

  const totalPages = Math.max(1, Math.ceil(staffList.length / pageSize));
  const paginatedStaff = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return staffList.slice(start, start + pageSize);
  }, [staffList, currentPage, pageSize]);

  // Derived KPI statistics
  const stats = useMemo(() => {
    return staffService.calculateStats(rawStaffList);
  }, [rawStaffList]);

  // Flash notification helper
  const showNotification = (type, message) => {
    setNotification({ type, message });
    setTimeout(() => {
      setNotification(null);
    }, 4000);
  };

  // Open modal for Adding
  const handleOpenAddModal = () => {
    setModalMode('add');
    setCurrentStaffId(null);
    setFormData({
      firstName: '',
      lastName: '',
      email: '',
      phone: '+94 ',
      department: 'Hardware Diagnostics & Repair',
      specialization: '',
      status: 'Active',
      password: '',
      confirmPassword: '',
      notes: '',
    });
    setFormErrors({});
    setFormGeneralError('');
    setIsModalOpen(true);
  };

  // Open modal for Editing (excludes password fields)
  const handleOpenEditModal = (staff) => {
    setModalMode('edit');
    setCurrentStaffId(staff.id);
    setFormData({
      firstName: staff.firstName,
      lastName: staff.lastName,
      email: staff.email,
      phone: staff.phone || '',
      department: staff.department || 'Hardware Diagnostics & Repair',
      specialization: staff.specialization || '',
      status: staff.status || 'Active',
      password: '',
      confirmPassword: '',
      notes: staff.notes || '',
    });
    setFormErrors({});
    setFormGeneralError('');
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setFormErrors({});
    setFormGeneralError('');
  };

  const handleFormChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if (formErrors[field]) {
      setFormErrors((prev) => ({ ...prev, [field]: '' }));
    }
  };

  // Open modal for Reset Password
  const handleOpenResetModal = (staff) => {
    setResetCandidate(staff);
    setResetPasswordData({ password: '', confirmPassword: '' });
    setResetErrors({});
    setResetGeneralError('');
    setIsResetModalOpen(true);
  };

  const handleCloseResetModal = () => {
    setIsResetModalOpen(false);
    setResetCandidate(null);
    setResetErrors({});
    setResetGeneralError('');
  };

  const handlePasswordDataChange = (field, value) => {
    setResetPasswordData((prev) => ({ ...prev, [field]: value }));
    if (resetErrors[field]) {
      setResetErrors((prev) => ({ ...prev, [field]: '' }));
    }
  };

  // Validation function for Add and Edit staff forms
  const validateStaffForm = () => {
    const errors = {};

    if (!formData.firstName.trim()) {
      errors.firstName = 'First name is required.';
    }

    if (!formData.lastName.trim()) {
      errors.lastName = 'Last name is required.';
    }

    const emailRegex = /^[^\s@]+@[^\s@]+$/;
    if (!formData.email.trim()) {
      errors.email = 'Email address is required.';
    } else if (!emailRegex.test(formData.email.trim())) {
      errors.email = 'Please enter a valid email address (e.g. technician@pcforge.com).';
    } else {
      const duplicate = rawStaffList.some(
        (s) =>
          (modalMode === 'add' || s.id !== currentStaffId) &&
          s.email.trim().toLowerCase() === formData.email.trim().toLowerCase()
      );
      if (duplicate) {
        errors.email = 'A staff account with this email address already exists.';
      }
    }

    const phoneClean = formData.phone.trim();
    const phoneRegex = /^(\+?[0-9\s\-()]{7,20})$/;
    if (!phoneClean) {
      errors.phone = 'Phone number is required.';
    } else if (!phoneRegex.test(phoneClean)) {
      errors.phone = 'Please enter a valid phone number (e.g. +94 77 123 4567).';
    }

    if (modalMode === 'add') {
      if (!formData.password) {
        errors.password = 'Account password is required.';
      } else if (formData.password.length < 6) {
        errors.password = 'Password must be at least 6 characters long.';
      }

      if (!formData.confirmPassword) {
        errors.confirmPassword = 'Confirming the password is required.';
      } else if (formData.password !== formData.confirmPassword) {
        errors.confirmPassword = 'Passwords do not match.';
      }
    }

    return errors;
  };

  // Submit modal form (Add or Edit)
  const handleFormSubmit = async (e) => {
    e.preventDefault();
    setFormGeneralError('');
    const errors = validateStaffForm();
    if (Object.keys(errors).length > 0) {
      setFormErrors(errors);
      setFormGeneralError('Please resolve the highlighted validation errors before saving.');
      return;
    }

    setSubmitting(true);
    try {
      if (modalMode === 'add') {
        const created = await staffService.addStaff(formData);
        setRawStaffList((prev) => [created, ...prev]);
        showNotification(
          'success',
          `Technician staff member "${created.firstName} ${created.lastName}" (${created.id}) was successfully registered.`
        );
      } else {
        const updated = await staffService.updateStaff(currentStaffId, {
          firstName: formData.firstName,
          lastName: formData.lastName,
          email: formData.email,
          phone: formData.phone,
          department: formData.department,
          specialization: formData.specialization,
          status: formData.status,
          notes: formData.notes,
        });
        setRawStaffList((prev) =>
          prev.map((s) => (s.id === currentStaffId || s.staffId === currentStaffId ? { ...s, ...updated } : s))
        );
        showNotification(
          'success',
          `Staff member "${updated.firstName} ${updated.lastName}" profile was successfully updated.`
        );
      }

      handleCloseModal();
    } catch (err) {
      setFormGeneralError(err.message || 'An error occurred while saving staff details.');
    } finally {
      setSubmitting(false);
    }
  };

  // Submit Reset Password modal
  const handleResetPasswordSubmit = async (e) => {
    e.preventDefault();
    setResetGeneralError('');
    const errors = {};

    if (!resetPasswordData.password) {
      errors.password = 'New password is required.';
    } else if (resetPasswordData.password.length < 6) {
      errors.password = 'New password must be at least 6 characters long.';
    }

    if (!resetPasswordData.confirmPassword) {
      errors.confirmPassword = 'Confirm password is required.';
    } else if (resetPasswordData.password !== resetPasswordData.confirmPassword) {
      errors.confirmPassword = 'Passwords do not match.';
    }

    if (Object.keys(errors).length > 0) {
      setResetErrors(errors);
      setResetGeneralError('Please check your passwords and try again.');
      return;
    }

    setResetSubmitting(true);
    try {
      await staffService.resetStaffPassword(resetCandidate.id, resetPasswordData.password);
      showNotification(
        'success',
        `Password for staff member "${resetCandidate.firstName} ${resetCandidate.lastName}" (${resetCandidate.id}) has been updated.`
      );
      handleCloseResetModal();
    } catch (err) {
      setResetGeneralError(err.message || 'Failed to update staff password.');
    } finally {
      setResetSubmitting(false);
    }
  };

  // Toggle status (Active <-> Inactive)
  const handleToggleStatus = async (staff) => {
    try {
      const updated = await staffService.toggleStaffStatus(staff.id);
      setRawStaffList((prev) =>
        prev.map((s) => (s.id === staff.id || s.staffId === staff.staffId ? { ...s, status: updated.status } : s))
      );
      showNotification(
        'success',
        `Staff member "${updated.firstName} ${updated.lastName}" is now marked as ${updated.status}.`
      );
    } catch (err) {
      showNotification('error', err.message || 'Failed to update staff status.');
    }
  };

  // Handle Delete
  const handleConfirmDelete = async () => {
    if (!deleteCandidate) return;
    try {
      await staffService.deleteStaff(deleteCandidate.id);
      setRawStaffList((prev) =>
        prev.filter((s) => s.id !== deleteCandidate.id && s.staffId !== deleteCandidate.staffId)
      );
      showNotification(
        'success',
        `Staff member "${deleteCandidate.firstName} ${deleteCandidate.lastName}" (${deleteCandidate.id}) has been removed.`
      );
      setDeleteCandidate(null);
    } catch (err) {
      showNotification('error', err.message || 'Failed to remove staff record.');
    }
  };

  // Reset Filters
  const handleResetFilters = () => {
    setSearchQuery('');
    setStatusFilter('all');
    setDepartmentFilter('all');
    setCurrentPage(1);
  };

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="dashboard-header">
        <div>
          <h1>Staff Management</h1>
          <p className="subtitle">Manage PCForge technician staff accounts and access.</p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <span className="badge badge-lg badge-admin">
            Admin Protected
          </span>
          <button onClick={handleOpenAddModal} className="btn btn-primary" id="add-staff-btn">
            + Add Staff
          </button>
        </div>
      </div>

      {/* Notification Banner */}
      {notification && (
        <div className={`notification-banner ${notification.type === 'success' ? 'alert-success' : 'alert-error'}`}>
          <span>{notification.message}</span>
          <button
            type="button"
            onClick={() => setNotification(null)}
            style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
            title="Dismiss"
          >
            <CloseIcon size={14} />
          </button>
        </div>
      )}

      {/* KPI Stats Cards */}
      <StaffStats stats={stats} />

      {/* Search & Filter Toolbar */}
      <StaffToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        onClearSearch={() => setSearchQuery('')}
        statusFilter={statusFilter}
        onStatusFilterChange={setStatusFilter}
        departmentFilter={departmentFilter}
        onDepartmentFilterChange={setDepartmentFilter}
        onResetFilters={handleResetFilters}
      />

      {/* Staff Table Section */}
      <StaffTable
        staffList={staffList}
        paginatedStaff={paginatedStaff}
        totalCount={stats.total}
        loading={loading}
        currentPage={currentPage}
        totalPages={totalPages}
        pageSize={pageSize}
        onPageChange={setCurrentPage}
        onPageSizeChange={(newSize) => {
          setPageSize(newSize);
          setCurrentPage(1);
        }}
        onResetFilters={handleResetFilters}
        onOpenAddModal={handleOpenAddModal}
        onView={setViewingStaff}
        onEdit={handleOpenEditModal}
        onResetPassword={handleOpenResetModal}
        onToggleStatus={handleToggleStatus}
        onDelete={setDeleteCandidate}
      />

      {/* Add / Edit Staff Modal */}
      <StaffFormModal
        isOpen={isModalOpen}
        modalMode={modalMode}
        onClose={handleCloseModal}
        formData={formData}
        onFormChange={handleFormChange}
        formErrors={formErrors}
        formGeneralError={formGeneralError}
        submitting={submitting}
        onSubmit={handleFormSubmit}
      />

      {/* Reset Password Modal */}
      <ResetPasswordModal
        isOpen={isResetModalOpen}
        candidate={resetCandidate}
        onClose={handleCloseResetModal}
        onSubmit={handleResetPasswordSubmit}
        passwordData={resetPasswordData}
        onChangePasswordData={handlePasswordDataChange}
        errors={resetErrors}
        generalError={resetGeneralError}
        submitting={resetSubmitting}
      />

      {/* Staff Details (View) Modal */}
      <ViewStaffModal
        staff={viewingStaff}
        onClose={() => setViewingStaff(null)}
        onOpenEdit={handleOpenEditModal}
        onOpenReset={handleOpenResetModal}
      />

      {/* Delete Confirmation Modal */}
      <DeleteStaffModal
        candidate={deleteCandidate}
        onClose={() => setDeleteCandidate(null)}
        onConfirm={handleConfirmDelete}
      />
    </div>
  );
};

export default StaffManagement;
