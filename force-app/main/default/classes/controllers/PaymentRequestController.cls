/**
 * @description Controller exposing Payment Request
 * operations to LWC components.
 * Thin layer — delegates to PaymentRequestService.
 */
public with sharing class PaymentRequestController {

    /**
     * @description Get payment requests for a merchant
     * cacheable=true for @wire support
     * @param merchantId - Merchant record Id
     * @return List of Payment Request records
     */
    @AuraEnabled(cacheable=true)
    public static List<Payment_Request__c> getRequestsForMerchant(
        Id merchantId
    ) {
        try {
            return PaymentRequestService.getRequestsForMerchant(
                merchantId
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Create a new payment request from LWC form
     * cacheable=false — performs DML
     * @param amount - Payment amount
     * @param dueDate - Due date string
     * @param merchantId - Parent merchant
     * @param customerId - Related customer
     * @param description - Optional description
     * @return New record Id
     */
    @AuraEnabled
    public static Id createPaymentRequest(
        Decimal amount,
        String  dueDate,
        Id      merchantId,
        Id      customerId,
        String  description
    ) {
        try {
            Payment_Request__c req = new Payment_Request__c();
            req.Amount__c      = amount;
            req.Due_Date__c    = Date.valueOf(dueDate);
            req.Merchant__c    = merchantId;
            req.Customer__c    = customerId;
            req.Description__c = description;

            return PaymentRequestService.createPaymentRequest(req);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Update payment request status
     * Used by row actions in the list component
     * @param requestId - Record to update
     * @param newStatus - Target status
     */
    @AuraEnabled
    public static void updateRequestStatus(
        Id     requestId,
        String newStatus
    ) {
        try {
            Payment_Request__c req = new Payment_Request__c(
                Id       = requestId,
                Status__c = newStatus
            );
            update req;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Get customers for a merchant
     * Populates customer dropdown in the form
     * @param merchantId - Parent merchant Id
     * @return List of Customer records
     */
    @AuraEnabled(cacheable=true)
    public static List<Customer__c> getCustomersForMerchant(
        Id merchantId
    ) {
        try {
            return [
                SELECT Id, Name, Email__c, Phone__c
                FROM Customer__c
                WHERE Merchant__c = :merchantId
                ORDER BY Name ASC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}