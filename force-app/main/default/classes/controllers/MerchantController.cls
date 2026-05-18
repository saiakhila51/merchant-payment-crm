/**
 * @description Controller class to expose Merchant actions to frontend components
 */
public with sharing class MerchantController {
    
    @AuraEnabled(cacheable=true)
    public static List<Merchant__c> getActiveMerchants() {
        return MerchantService.getActiveMerchants();
    } 
    
    @AuraEnabled
    public static Id createMerchant(Merchant__c merchant) { 
        return MerchantService.createMerchant(merchant); 
    }

    @AuraEnabled(cacheable=true)
    public static Merchant__c getMerchantDetails(Id merchantId) {
        return MerchantService.getMerchantDetails(merchantId);
    }
    /**
 * @description Wrapper to send merchant stats to LWC
 * LWC cannot directly receive complex calculations
 * Wrapper pattern is industry standard for this
 */
public class MerchantStats {
    @AuraEnabled public Integer totalMerchants;
    @AuraEnabled public Integer activeMerchants;
    @AuraEnabled public Integer suspendedMerchants;
    @AuraEnabled public Integer highRiskMerchants;

    public MerchantStats(
        Integer total,
        Integer active,
        Integer suspended,
        Integer highRisk
    ) {
        this.totalMerchants     = total;
        this.activeMerchants    = active;
        this.suspendedMerchants = suspended;
        this.highRiskMerchants  = highRisk;
    }
}

/**
 * @description Get merchant summary stats for dashboard header
 * @return MerchantStats wrapper object
 */
@AuraEnabled(cacheable=true)
public static MerchantStats getMerchantStats() {
    try {
        List<Merchant__c> all = [
            SELECT Id, Status__c, Risk_Score__c
            FROM Merchant__c
        ];

        Integer active    = 0;
        Integer suspended = 0;
        Integer highRisk  = 0;

        for (Merchant__c m : all) {
            if (m.Status__c == 'Active')    active++;
            if (m.Status__c == 'Suspended') suspended++;
            if (m.Risk_Score__c >= 70)      highRisk++;
        }

        return new MerchantStats(
            all.size(), active, suspended, highRisk
        );
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
}
