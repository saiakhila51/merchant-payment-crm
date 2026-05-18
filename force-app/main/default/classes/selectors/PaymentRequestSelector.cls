/**
 * @description Selector class for Payment_Request__c object.
 * All payment request queries go here.
 */
public with sharing class PaymentRequestSelector {

    /**
     * @description Get all payment requests for a merchant
     * @param merchantId - Merchant Id
     * @return List of Payment Requests
     */
    public static List<Payment_Request__c> getRequestsByMerchant(Id merchantId) {
        return [
            SELECT Id,
                   Name,
                   Amount__c,
                   Status__c,
                   Due_Date__c,
                   Attempts__c,
                   Last_Attempt_Date__c,
                   Customer__c,
                   Customer__r.Name,
                   Merchant__c,
                   CreatedDate
            FROM Payment_Request__c
            WHERE Merchant__c = :merchantId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
    }

    /**
     * @description Get overdue pending requests
     * Used by scheduled Apex for reminder automation
     * @return List of overdue Payment Requests
     */
    public static List<Payment_Request__c> getOverdueRequests() {
        return [
            SELECT Id,
                   Name,
                   Amount__c,
                   Due_Date__c,
                   Merchant__c,
                   Merchant__r.Email__c,
                   Merchant__r.Business_Name__c,
                   Customer__r.Name
            FROM Payment_Request__c
            WHERE Status__c = 'Pending'
            AND Due_Date__c < TODAY
            ORDER BY Due_Date__c ASC
        ];
    }

    /**
     * @description Get failed requests by merchant ids
     * Bulk-safe — takes a Set of Ids
     * @param merchantIds - Set of Merchant Ids
     * @return List of failed Payment Requests
     */
    public static List<Payment_Request__c> getFailedRequestsByMerchants(
        Set<Id> merchantIds
    ) {
        return [
            SELECT Id,
                   Name,
                   Amount__c,
                   Attempts__c,
                   Merchant__c,
                   Status__c
            FROM Payment_Request__c
            WHERE Status__c = 'Failed'
            AND Merchant__c IN :merchantIds
        ];
    }
}