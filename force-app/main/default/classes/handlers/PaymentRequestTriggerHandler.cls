/**
 * @description Handler class for PaymentRequestTrigger.
 * Decides which service methods to invoke.
 * Contains routing logic only — no business logic.
 */
public with sharing class PaymentRequestTriggerHandler {

    /**
     * @description Before insert — set default field values
     * Use BEFORE because we're modifying the record itself
     * @param newRequests - List of new Payment Request records
     */
    public void onBeforeInsert(List<Payment_Request__c> newRequests) {
        PaymentRequestService.setDefaultValues(newRequests);
    }

    /**
     * @description Before update — validate status transitions
     * Prevents invalid status changes like Paid → Pending
     * @param newRequests - Updated records
     * @param oldMap - Previous state of records
     */
    public void onBeforeUpdate(
        List<Payment_Request__c> newRequests,
        Map<Id, Payment_Request__c> oldMap
    ) {
        PaymentRequestService.validateStatusTransition(
            newRequests,
            oldMap
        );
    }

    /**
     * @description After insert — create notification log
     * Use AFTER because we need the record Id
     * @param newRequests - Newly inserted records
     */
    public void onAfterInsert(List<Payment_Request__c> newRequests) {
        PaymentRequestService.createNotificationLogs(
            newRequests,
            'Payment Request Created'
        );
    }

    /**
     * @description After update — handle status change logic
     * Fires risk scoring, dispute creation, notifications
     * @param newRequests - Updated records
     * @param oldMap - Previous state
     */
    public void onAfterUpdate(
        List<Payment_Request__c> newRequests,
        Map<Id, Payment_Request__c> oldMap
    ) {
        // Collect only records where status actually changed
        List<Payment_Request__c> statusChanged =
            new List<Payment_Request__c>();
        Set<Id> merchantIds = new Set<Id>();

        for (Payment_Request__c req : newRequests) {
            Payment_Request__c oldReq = oldMap.get(req.Id);

            if (req.Status__c != oldReq.Status__c) {
                statusChanged.add(req);
                merchantIds.add(req.Merchant__c);
            }
        }

        // Only process if something actually changed
        if (!statusChanged.isEmpty()) {
            PaymentRequestService.handleStatusChange(
                statusChanged,
                oldMap
            );
        }

        if (!merchantIds.isEmpty()) {
            MerchantService.updateRiskScores(merchantIds);
        }
    }
}