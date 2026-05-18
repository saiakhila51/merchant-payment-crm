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
}