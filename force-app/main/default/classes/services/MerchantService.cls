/**
 * @description Service class for Merchant business logic.
 * Handles merchant operations, risk scoring, status management.
 * Calls MerchantSelector for data — never writes SOQL directly.
 */
public with sharing class MerchantService {

    // Risk score thresholds — defined as constants
    private static final Integer HIGH_RISK_THRESHOLD = 70;
    private static final Integer MEDIUM_RISK_THRESHOLD = 40;

    /**
     * @description Get all active merchants for dashboard display
     * @return List of active merchants
     */
    public static List<Merchant__c> getActiveMerchants() {
        return MerchantSelector.getActiveMerchants();
    }

    /**
     * @description Get merchant details by Id
     * @param merchantId - Record Id
     * @return Merchant record or null
     */
    public static Merchant__c getMerchantDetails(Id merchantId) {
        if (merchantId == null) {
            throw new MerchantServiceException('Merchant Id cannot be null');
        }
        return MerchantSelector.getMerchantById(merchantId);
    }

    /**
     * @description Create a new merchant record
     * Applies default values and business rules
     * @param merchant - Merchant record to insert
     * @return Inserted merchant Id
     */
    public static Id createMerchant(Merchant__c merchant) {
        // Business rule: set default values
        merchant.Status__c = 'Active';
        merchant.Risk_Score__c = 0;
        merchant.Onboarding_Date__c = Date.today();
        merchant.KYC_Verified__c = false;

        try {
            insert merchant;
            return merchant.Id;
        } catch (DmlException e) {
            throw new MerchantServiceException(
                'Failed to create merchant: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Calculate and update merchant risk score
     * Risk logic: based on failed transactions
     * @param merchantId - Merchant to evaluate
     */
    public static void updateRiskScore(Id merchantId) {
        Merchant__c merchant = MerchantSelector.getMerchantById(merchantId);

        if (merchant == null) return;

        // Get failed payment count for this merchant
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

        // Calculate risk score (0-100)
        Integer riskScore = 0;
        if (totalCount > 0) {
            Decimal failureRate = (Decimal.valueOf(failedCount) /
                                   Decimal.valueOf(totalCount)) * 100;
            riskScore = failureRate.intValue();
        }

        // High value bonus risk
        if (riskScore >= HIGH_RISK_THRESHOLD) {
            merchant.Status__c = 'Suspended';
        }

        merchant.Risk_Score__c = riskScore;

        try {
            update merchant;
        } catch (DmlException e) {
            throw new MerchantServiceException(
                'Failed to update risk score: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Custom exception class for MerchantService
     * Best practice: always define domain-specific exceptions
     */
    public class MerchantServiceException extends Exception {}
}