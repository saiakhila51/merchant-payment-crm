/**
 * @description Selector class for Merchant__c object.
 * Centralizes all SOQL queries for merchants.
 * Follows selector pattern for bulkification and reusability.
 */
public with sharing class MerchantSelector {

    /**
     * @description Returns all active merchants
     * @return List of active Merchant records
     */
    public static List<Merchant__c> getActiveMerchants() {
        return [
            SELECT Id,
                   Name,
                   Business_Name__c,
                   Email__c,
                   Phone__c,
                   Status__c,
                   Merchant_Category__c,
                   Risk_Score__c,
                   KYC_Verified__c,
                   Onboarding_Date__c,
                   Total_Payment_Requests__c
            FROM Merchant__c
            WHERE Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    /**
     * @description Returns a single merchant by Id
     * @param merchantId - Id of the merchant
     * @return Single Merchant record
     */
    public static Merchant__c getMerchantById(Id merchantId) {
        List<Merchant__c> results = [
            SELECT Id,
                   Name,
                   Business_Name__c,
                   Email__c,
                   Phone__c,
                   Status__c,
                   Risk_Score__c,
                   KYC_Verified__c,
                   Total_Payment_Requests__c
            FROM Merchant__c
            WHERE Id = :merchantId
            LIMIT 1
        ];

        // Safe return — never assume record exists
        return results.isEmpty() ? null : results[0];
    }

    /**
     * @description Returns merchants by a list of Ids
     * Used for bulk operations — avoids SOQL in loops
     * @param merchantIds - Set of merchant Ids
     * @return Map of Id to Merchant record
     */
    public static Map<Id, Merchant__c> getMerchantsByIds(Set<Id> merchantIds) {
        return new Map<Id, Merchant__c>([
            SELECT Id,
                   Name,
                   Business_Name__c,
                   Email__c,
                   Status__c,
                   Risk_Score__c
            FROM Merchant__c
            WHERE Id IN :merchantIds
        ]);
    }
}