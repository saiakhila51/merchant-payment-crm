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
/**
 * @description Bulk risk score update — bulk safe
 * Called from trigger handler with set of merchant Ids
 * @param merchantIds - Set of merchant Ids to update
 */
public static void updateRiskScores(Set<Id> merchantIds) {
    if (merchantIds.isEmpty()) return;

    // One SOQL — get all failed counts grouped
    // AggregateResult — advanced but important
    Map<Id, Integer> failedCountMap = new Map<Id, Integer>();
    Map<Id, Integer> totalCountMap  = new Map<Id, Integer>();

    for (AggregateResult ar : [
        SELECT Merchant__c, COUNT(Id) cnt
        FROM Payment_Request__c
        WHERE Merchant__c IN :merchantIds
        AND Status__c = 'Failed'
        GROUP BY Merchant__c
    ]) {
        failedCountMap.put(
            (Id)ar.get('Merchant__c'),
            (Integer)ar.get('cnt')
        );
    }

    for (AggregateResult ar : [
        SELECT Merchant__c, COUNT(Id) cnt
        FROM Payment_Request__c
        WHERE Merchant__c IN :merchantIds
        GROUP BY Merchant__c
    ]) {
        totalCountMap.put(
            (Id)ar.get('Merchant__c'),
            (Integer)ar.get('cnt')
        );
    }

    // Get merchant records to update
    Map<Id, Merchant__c> merchantMap =
        MerchantSelector.getMerchantsByIds(merchantIds);

    List<Merchant__c> toUpdate = new List<Merchant__c>();

    for (Id mId : merchantIds) {
        Merchant__c merchant = merchantMap.get(mId);
        if (merchant == null) continue;

        Integer failed = failedCountMap.containsKey(mId) ?
            failedCountMap.get(mId) : 0;
        Integer total  = totalCountMap.containsKey(mId) ?
            totalCountMap.get(mId) : 0;

        Integer riskScore = 0;
        if (total > 0) {
            riskScore = ((Decimal.valueOf(failed) /
                Decimal.valueOf(total)) * 100).intValue();
        }

        merchant.Risk_Score__c = riskScore;

        if (riskScore >= HIGH_RISK_THRESHOLD) {
            merchant.Status__c = 'Suspended';
        }

        toUpdate.add(merchant);
    }

    if (!toUpdate.isEmpty()) {
        try {
            update toUpdate;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR,
                'Risk score update failed: ' + e.getMessage()
            );
        }
    }
}