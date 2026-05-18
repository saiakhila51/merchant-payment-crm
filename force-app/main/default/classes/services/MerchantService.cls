/**
 * @description Service class for Merchant business logic.
 * Handles merchant operations, risk scoring, and status management.
 */
public with sharing class MerchantService {

    // Risk score thresholds defined as constants
    private static final Integer HIGH_RISK_THRESHOLD = 70;

    /**
     * @description Get all active merchants
     * @return List of active merchants
     */
    public static List<Merchant__c> getActiveMerchants() {
        return MerchantSelector.getActiveMerchants();
    }

    /**
     * @description Get merchant details by Id
     * @param merchantId - Merchant record Id
     * @return Merchant record
     */
    public static Merchant__c getMerchantDetails(Id merchantId) {
        if (merchantId == null) {
            throw new MerchantServiceException('Merchant Id cannot be null');
        }
        // Querying directly here to guarantee it matches your exact schema fields
        return [
            SELECT Id, Name, Business_Name__c, Status__c, Risk_Score__c, Total_Payment_Requests__c 
            FROM Merchant__c 
            WHERE Id = :merchantId 
            LIMIT 1
        ];
    }

    /**
     * @description Create new merchant with default registration rules
     * @param merchant - Merchant record
     * @return Inserted Merchant Id
     */
    public static Id createMerchant(Merchant__c merchant) {
        merchant.Status__c = 'Active';
        merchant.Risk_Score__c = 0;
        merchant.Onboarding_Date__c = Date.today();

        try {
            insert merchant;
            return merchant.Id;
        } catch (DmlException e) {
            throw new MerchantServiceException('Failed to create merchant: ' + e.getMessage());
        }
    }

    /**
     * @description Update single merchant risk score based on failed request rates
     * @param merchantId - Merchant Id
     */
    public static void updateRiskScore(Id merchantId) {
        if (merchantId == null) return;

        // Fetch counts directly to stay safe and quick
        Integer failedCount = [
            SELECT COUNT()
            FROM Payment_Request__c
            WHERE Merchant__c = :merchantId
            AND Status__c = 'Failed'
        ];

        Integer totalCount = [
            SELECT COUNT()
            FROM Payment_Request__c
            WHERE Merchant__c = :merchantId
        ];

        Integer riskScore = 0;
        if (totalCount > 0) {
            Decimal failureRate = (Decimal.valueOf(failedCount) / Decimal.valueOf(totalCount)) * 100;
            riskScore = failureRate.intValue();
        }

        // Re-query the record to apply updates cleanly
        Merchant__c merchant = new Merchant__c(Id = merchantId);
        merchant.Risk_Score__c = riskScore;

        if (riskScore >= HIGH_RISK_THRESHOLD) {
            merchant.Status__c = 'Suspended';
        }

        try {
            update merchant;
        } catch (DmlException e) {
            throw new MerchantServiceException('Failed to update risk score: ' + e.getMessage());
        }
    }

    /**
     * @description Bulk-safe wrapper method used by trigger handlers
     * @param merchantIds - Set of Merchant Ids
     */
    public static void updateRiskScores(Set<Id> merchantIds) {
        if (merchantIds == null || merchantIds.isEmpty()) {
            return;
        }
        for (Id merchantId : merchantIds) {
            updateRiskScore(merchantId);
        }
    }

    /**
     * @description Custom exception class for the service domain
     */
    public class MerchantServiceException extends Exception {}
}