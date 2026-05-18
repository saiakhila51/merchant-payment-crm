/**
 * @description Service class for Payment Request business logic.
 * Handles status lifecycle, validation, notifications, disputes.
 * Called by trigger handler and LWC controllers.
 */
public with sharing class PaymentRequestService {

    // Valid status transitions — fintech rule
    // Key = current status, Value = allowed next statuses
    private static final Map<String, Set<String>> VALID_TRANSITIONS =
        new Map<String, Set<String>>{
            'Pending'  => new Set<String>{'Paid', 'Failed', 'Expired'},
            'Failed'   => new Set<String>{'Pending', 'Refunded'},
            'Paid'     => new Set<String>{'Refunded'},
            'Refunded' => new Set<String>(),
            'Expired'  => new Set<String>()
        };

    private static final Integer MAX_ATTEMPTS_BEFORE_FLAG = 3;
    private static final Decimal HIGH_VALUE_THRESHOLD = 50000;

    // ─────────────────────────────────────────
    // BEFORE INSERT
    // ─────────────────────────────────────────

    /**
     * @description Sets default values on new payment requests
     * Runs before insert so values save with the record
     * @param requests - New payment request records
     */
    public static void setDefaultValues(
        List<Payment_Request__c> requests
    ) {
        for (Payment_Request__c req : requests) {
            // Default status
            if (String.isBlank(req.Status__c)) {
                req.Status__c = 'Pending';
            }

            // Default attempts
            if (req.Attempts__c == null) {
                req.Attempts__c = 0;
            }

            // Generate mock payment link
            if (String.isBlank(req.Payment_Link__c)) {
                req.Payment_Link__c =
                    'https://pay.merchantcrm.io/' +
                    generateMockToken();
            }
        }
    }

    // ─────────────────────────────────────────
    // BEFORE UPDATE
    // ─────────────────────────────────────────

    /**
     * @description Validates status transitions
     * Prevents invalid transitions like Paid → Pending
     * Adds error directly to the record field
     * @param newRequests - Updated records
     * @param oldMap - Previous state
     */
    public static void validateStatusTransition(
        List<Payment_Request__c> newRequests,
        Map<Id, Payment_Request__c> oldMap
    ) {
        for (Payment_Request__c req : newRequests) {
            String oldStatus = oldMap.get(req.Id).Status__c;
            String newStatus = req.Status__c;

            // Skip if status hasn't changed
            if (oldStatus == newStatus) continue;

            // Check if transition is valid
            Set<String> allowed = VALID_TRANSITIONS.get(oldStatus);

            if (allowed == null || !allowed.contains(newStatus)) {
                // addError prevents the save entirely
                req.Status__c.addError(
                    'Invalid status transition from ' +
                    oldStatus + ' to ' + newStatus +
                    '. Allowed: ' + (allowed != null ?
                    String.join(new List<String>(allowed), ', ') :
                    'None')
                );
            }
        }
    }

    // ─────────────────────────────────────────
    // AFTER INSERT
    // ─────────────────────────────────────────

    /**
     * @description Creates notification log entries
     * Called after insert/update when notifications needed
     * Bulk-safe — collects all logs and does one DML
     * @param requests - Trigger records
     * @param notificationType - Type of notification
     */
    public static void createNotificationLogs(
        List<Payment_Request__c> requests,
        String notificationType
    ) {
        List<Notification_Log__c> logs =
            new List<Notification_Log__c>();

        for (Payment_Request__c req : requests) {
            Notification_Log__c log = new Notification_Log__c();
            log.Merchant__c       = req.Merchant__c;
            log.Notification_Type__c = notificationType;
            log.Sent_Date__c      = DateTime.now();
            log.Status__c         = 'Sent';
            log.Channel__c        = 'In-App';
            log.Message__c        =
                'Payment request ' + req.Name +
                ' for ₹' + req.Amount__c +
                ' — Status: ' + req.Status__c;

            logs.add(log);
        }

        if (!logs.isEmpty()) {
            try {
                insert logs;
            } catch (DmlException e) {
                // Log error but don't fail the main transaction
                System.debug(LoggingLevel.ERROR,
                    'Notification log insert failed: ' +
                    e.getMessage()
                );
            }
        }
    }

    // ─────────────────────────────────────────
    // AFTER UPDATE
    // ─────────────────────────────────────────

    /**
     * @description Central handler for status changes
     * Routes to specific handlers based on new status
     * @param changedRequests - Records with changed status
     * @param oldMap - Previous state
     */
    public static void handleStatusChange(
        List<Payment_Request__c> changedRequests,
        Map<Id, Payment_Request__c> oldMap
    ) {
        List<Payment_Request__c> failedRequests =
            new List<Payment_Request__c>();
        List<Payment_Request__c> paidRequests =
            new List<Payment_Request__c>();

        for (Payment_Request__c req : changedRequests) {
            if (req.Status__c == 'Failed') {
                failedRequests.add(req);
            } else if (req.Status__c == 'Paid') {
                paidRequests.add(req);
            }
        }

        // Handle failed payments
        if (!failedRequests.isEmpty()) {
            handleFailedPayments(failedRequests);
        }

        // Handle successful payments
        if (!paidRequests.isEmpty()) {
            createNotificationLogs(paidRequests, 'Payment Success');
        }
    }

    /**
     * @description Handles failed payment logic
     * Increments attempts, flags fraud risk, auto-creates dispute
     * @param failedRequests - Failed payment request records
     */
    private static void handleFailedPayments(
        List<Payment_Request__c> failedRequests
    ) {
        List<Payment_Request__c> toUpdate =
            new List<Payment_Request__c>();
        List<Dispute__c> disputesToCreate =
            new List<Dispute__c>();

        for (Payment_Request__c req : failedRequests) {
            // Increment attempts counter
            Payment_Request__c updateReq = new Payment_Request__c(
                Id = req.Id,
                Attempts__c = (req.Attempts__c == null ?
                    1 : req.Attempts__c + 1),
                Last_Attempt_Date__c = DateTime.now()
            );
            toUpdate.add(updateReq);

            // Auto-create dispute after max attempts
            if (req.Attempts__c >= MAX_ATTEMPTS_BEFORE_FLAG) {
                Dispute__c dispute = new Dispute__c();
                dispute.Raised_Date__c   = Date.today();
                dispute.Status__c        = 'Open';
                dispute.Priority__c      = req.Amount__c >=
                    HIGH_VALUE_THRESHOLD ? 'Critical' : 'High';
                dispute.Dispute_Reason__c = 'Not Received';
                disputesToCreate.add(dispute);
            }
        }

        // Bulk DML — one call for all updates
        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR,
                    'Failed to update attempts: ' + e.getMessage()
                );
            }
        }

        // Bulk DML — one call for all disputes
        if (!disputesToCreate.isEmpty()) {
            try {
                insert disputesToCreate;
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR,
                    'Failed to create disputes: ' + e.getMessage()
                );
            }
        }

        // Send failure notifications
        createNotificationLogs(failedRequests, 'Failure Alert');
    }

    // ─────────────────────────────────────────
    // LWC CONTROLLER METHODS
    // ─────────────────────────────────────────

    /**
     * @description Get payment requests for merchant dashboard
     * @param merchantId - Merchant record Id
     * @return List of payment requests
     */
    public static List<Payment_Request__c> getRequestsForMerchant(
        Id merchantId
    ) {
        if (merchantId == null) {
            throw new PaymentServiceException(
                'Merchant Id is required'
            );
        }
        return PaymentRequestSelector.getRequestsByMerchant(
            merchantId
        );
    }

    /**
     * @description Create new payment request
     * @param request - Payment request record from LWC
     * @return Created record Id
     */
    public static Id createPaymentRequest(
        Payment_Request__c request
    ) {
        try {
            insert request;
            return request.Id;
        } catch (DmlException e) {
            throw new PaymentServiceException(
                'Failed to create payment request: ' +
                e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────

    /**
     * @description Generates a mock payment token
     * Simulates what a real payment gateway would generate
     * @return Random token string
     */
    private static String generateMockToken() {
        return EncodingUtil.convertToHex(
            Crypto.generateAesKey(128)
        ).substring(0, 16);
    }

    /**
     * @description Custom exception for payment service errors
     */
    public class PaymentServiceException extends Exception {}
}