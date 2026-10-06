import React, { useState, useEffect, useMemo } from 'react';
import { buildReviewService } from '../services/buildReviewService.js';
import { useAuth } from '../context/AuthContext.jsx';
import {
  BuildReviewStats,
  BuildReviewToolbar,
  BuildReviewTable,
  BuildWorkbenchModal,
} from '../components/builds';
import { ToolsIcon, RefreshCwIcon, CloseIcon } from '../components/icons';

export const BuildReviews = () => {
  const { user } = useAuth();

  const [builds, setBuilds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Selected build for detailed inspection modal
  const [selectedBuild, setSelectedBuild] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Technician review form state
  const [technicianNotes, setTechnicianNotes] = useState('');
  const [validationError, setValidationError] = useState('');

  // Toast notification
  const [notification, setNotification] = useState(null);

  const showNotification = (message, type = 'success') => {
    setNotification({ message, type });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  // Load builds
  const loadData = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      const buildsResult = await buildReviewService.fetchBuilds();
      if (Array.isArray(buildsResult)) {
        setBuilds(buildsResult);
      }
    } catch (err) {
      console.error('Error loading build review queue:', err);
      showNotification('Failed to fetch build reviews from backend.', 'error');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Reset pagination on filter change
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, statusFilter]);

  // Filtered builds
  const filteredBuilds = useMemo(() => {
    return builds.filter((b) => {
      // 1. Status Filter
      if (statusFilter !== 'all' && (b.status || '').toLowerCase() !== statusFilter.toLowerCase()) {
        return false;
      }

      // 2. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.trim().toLowerCase();
        const cleanId = q.replace(/^#/, '');
        const matchId = String(b.buildId).includes(cleanId);
        const matchName = (b.buildName || '').toLowerCase().includes(q);
        const matchCustomer = (b.customerName || '').toLowerCase().includes(q);
        const matchEmail = (b.customerEmail || '').toLowerCase().includes(q);
        const matchNotes = (b.customerNotes || '').toLowerCase().includes(q);
        if (!matchId && !matchName && !matchCustomer && !matchEmail && !matchNotes) {
          return false;
        }
      }

      return true;
    });
  }, [builds, statusFilter, searchQuery]);

  const totalPages = Math.max(1, Math.ceil(filteredBuilds.length / pageSize));
  const paginatedBuilds = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredBuilds.slice(start, start + pageSize);
  }, [filteredBuilds, currentPage, pageSize]);

  // Summary Metrics
  const metrics = useMemo(() => {
    const total = builds.length;
    const pending = builds.filter((b) => b.status === 'Pending Staff Review').length;
    const inReview = builds.filter((b) => b.status === 'In Review by Staff').length;
    const approved = builds.filter((b) => b.status === 'Approved by Staff').length;
    const changesRequested = builds.filter((b) => b.status === 'Changes Requested').length;

    return { total, pending, inReview, approved, changesRequested };
  }, [builds]);

  // Open inspection modal
  const handleOpenInspection = async (build) => {
    setSelectedBuild(build);
    setTechnicianNotes(build.staffNotes || '');
    setValidationError('');

    try {
      const detailed = await buildReviewService.getBuildById(build.buildId);
      if (detailed) {
        setSelectedBuild(detailed);
        setTechnicianNotes(detailed.staffNotes || '');
      }
    } catch (err) {
      console.warn('Using cached build details:', err);
    }
  };

  const handleCloseModal = () => {
    setSelectedBuild(null);
    setTechnicianNotes('');
    setValidationError('');
  };

  const handleStatusTransition = async (newStatus) => {
    if (!selectedBuild) return;

    if (newStatus === 'Changes Requested' && !technicianNotes.trim()) {
      setValidationError('Please provide technical feedback explaining what components need modification.');
      return;
    }

    setActionLoading(true);
    setValidationError('');

    try {
      const notesToSave = technicianNotes.trim() || 
        (newStatus === 'Approved by Staff' 
          ? 'Hardware clearances verified on workbench. Automated checks passed. Cleared for assembly.' 
          : selectedBuild.staffNotes);

      const updated = await buildReviewService.updateBuildReview(selectedBuild.buildId, {
        status: newStatus,
        staffNotes: notesToSave,
      });

      setSelectedBuild(updated);
      await loadData();
      showNotification(`Build #${selectedBuild.buildId} status updated to '${newStatus}'.`);

      if (newStatus === 'Approved by Staff') {
        setTimeout(handleCloseModal, 1200);
      }
    } catch (err) {
      showNotification(`Failed to update build status: ${err?.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleResetFilters = () => {
    setSearchQuery('');
    setStatusFilter('all');
    setCurrentPage(1);
  };

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="dashboard-header">
        <div>
          <h1 style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <ToolsIcon size={28} /> Custom Build Clearance
          </h1>
          <p className="subtitle">
            Validate component clearances, PSU headroom, and approve customer PC builds.
          </p>
        </div>
        <div className="header-actions">
          <button
            type="button"
            onClick={() => loadData(true)}
            disabled={refreshing}
            className="btn btn-outline"
            id="refresh-builds-btn"
          >
            {refreshing ? (
              'Refreshing...'
            ) : (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
                <RefreshCwIcon size={14} /> Refresh Queue
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Notification Toast */}
      {notification && (
        <div
          className={`notification-banner ${
            notification.type === 'error' ? 'alert-error' : 'alert-success'
          }`}
        >
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

      {/* KPI Stats Row */}
      <BuildReviewStats metrics={metrics} />

      {/* Toolbar & Filter Card */}
      <BuildReviewToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        onClearSearch={() => setSearchQuery('')}
        statusFilter={statusFilter}
        onStatusFilterChange={setStatusFilter}
        metrics={metrics}
        onResetFilters={handleResetFilters}
      />

      {/* Main Review Queue Table */}
      <BuildReviewTable
        builds={filteredBuilds}
        paginatedBuilds={paginatedBuilds}
        totalCount={metrics.total}
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
        onInspect={handleOpenInspection}
      />

      {/* Modal: Full Inspection & Clearance Workbench */}
      <BuildWorkbenchModal
        build={selectedBuild}
        onClose={handleCloseModal}
        technicianNotes={technicianNotes}
        onNotesChange={setTechnicianNotes}
        validationError={validationError}
        actionLoading={actionLoading}
        onStatusTransition={handleStatusTransition}
      />
    </div>
  );
};

export default BuildReviews;
