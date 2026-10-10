import emailjs from '@emailjs/browser';

/**
 * Checks if EmailJS environment variables are configured with valid values.
 */
export const isEmailJsConfigured = () => {
  const serviceId = import.meta.env.VITE_EMAILJS_SERVICE_ID;
  const templateId = import.meta.env.VITE_EMAILJS_TEMPLATE_ID;
  const publicKey = import.meta.env.VITE_EMAILJS_PUBLIC_KEY;

  if (!serviceId || !templateId || !publicKey) return false;
  const dummyPatterns = ['your_', 'placeholder', 'dummy', 'change_me', 'xxx'];
  if (
    dummyPatterns.some(
      (pattern) =>
        serviceId.toLowerCase().includes(pattern) ||
        templateId.toLowerCase().includes(pattern) ||
        publicKey.toLowerCase().includes(pattern)
    )
  ) {
    return false;
  }
  return true;
};

/**
 * Sends a notification email to the customer regarding their custom PC build review.
 * Automatically triggered when technician marks build as 'Approved by Staff' or 'Changes Requested'.
 *
 * @param {Object} options
 * @param {string} options.customerName - Name of the customer
 * @param {string} options.customerEmail - Email address of the customer
 * @param {number|string} options.buildId - ID of the custom build
 * @param {string} options.buildName - Name of the build
 * @param {string} options.newStatus - 'Approved by Staff' | 'Changes Requested'
 * @param {string} options.technicianNotes - Feedback / assembly instructions
 * @param {number|string} [options.totalPrice] - Total price of the build
 * @returns {Promise<{success: boolean, simulated?: boolean, status?: number, text?: string, error?: string, message?: string}>}
 */
export const sendBuildReviewNotification = async ({
  customerName = 'Valued Customer',
  customerEmail,
  buildId,
  buildName = 'Custom PC Build',
  newStatus,
  technicianNotes = '',
  totalPrice,
}) => {
  if (!customerEmail) {
    console.warn('[EmailJS] Notification skipped: customer email is not provided.');
    return { success: false, error: 'Customer email is required' };
  }

  const isApproved = newStatus === 'Approved by Staff';
  const statusBadge = isApproved ? 'APPROVED' : 'CHANGES REQUESTED';
  const subject = isApproved
    ? `PCForge: Your Custom PC Build #${buildId} has been Approved!`
    : `PCForge: Modifications Requested for Build #${buildId}`;

  const message = isApproved
    ? `Great news! Our certified technicians have reviewed and approved your custom PC build "${buildName}" (Build #${buildId}). All component clearances, power envelopes, and thermal metrics have passed verification. Your build is now cleared for assembly!`
    : `Our technicians have reviewed your custom PC build "${buildName}" (Build #${buildId}) and requested some adjustments. Please check the technician feedback notes below and update your configuration in the PCForge app.`;

  const templateParams = {
    to_name: customerName || 'Valued Customer',
    to_email: customerEmail,
    customer_name: customerName || 'Valued Customer',
    customer_email: customerEmail,
    build_id: String(buildId),
    build_name: buildName,
    status: newStatus,
    review_status: statusBadge,
    subject: subject,
    technician_notes:
      technicianNotes ||
      (isApproved ? 'All checks passed. Cleared for assembly.' : 'Adjustments needed.'),
    staff_notes:
      technicianNotes ||
      (isApproved ? 'All checks passed. Cleared for assembly.' : 'Adjustments needed.'),
    total_price: totalPrice ? `LKR ${Number(totalPrice).toFixed(2)}` : 'N/A',
    message: message,
    action_url: `${typeof window !== 'undefined' ? window.location.origin : 'http://localhost:5173'}/builds`,
  };

  const serviceId = import.meta.env.VITE_EMAILJS_SERVICE_ID;
  const templateId = import.meta.env.VITE_EMAILJS_TEMPLATE_ID;
  const publicKey = import.meta.env.VITE_EMAILJS_PUBLIC_KEY;

  if (!isEmailJsConfigured()) {
    console.log(
      `[EmailJS] (Simulated Mode - Set real keys in web/.env to transmit)\n` +
      `To: ${customerEmail} (${customerName})\n` +
      `Subject: ${subject}\n` +
      `Status: ${newStatus}\n` +
      `Notes: ${templateParams.technician_notes}\n` +
      `Payload:`,
      templateParams
    );
    return {
      success: true,
      simulated: true,
      message:
        'Simulated email notification dispatched. Set VITE_EMAILJS_PUBLIC_KEY in .env for live transmission.',
    };
  }

  try {
    const result = await emailjs.send(serviceId, templateId, templateParams, publicKey);
    console.log('[EmailJS] Notification successfully sent to:', customerEmail, result);
    return {
      success: true,
      simulated: false,
      status: result?.status,
      text: result?.text,
    };
  } catch (error) {
    console.error('[EmailJS] Failed to send email to customer:', error);
    return {
      success: false,
      simulated: false,
      error: error?.text || error?.message || 'Failed to dispatch email via EmailJS',
    };
  }
};

export const emailService = {
  isEmailJsConfigured,
  sendBuildReviewNotification,
};

export default emailService;
