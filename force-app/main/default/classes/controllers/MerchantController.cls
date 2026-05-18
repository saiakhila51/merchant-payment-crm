/**
 * @description Controller class exposing Merchant operations to LWC.
 * Annotated with @AuraEnabled for LWC access.
 * Thin layer — delegates all logic to MerchantService.
 */
public with sharing class MerchantController {

    /**
     * @description Get all active merchants for LWC dashboard
     * cacheable=true allows LWC @wire to cache results
     * @return List of Merchant records
     */
    @AuraEnabled(cacheable=true)
    public static List<Merchant__c> getActiveMerchants() {
        try {
            return MerchantService.getActiveMerchants();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Get single merchant details
     * @param merchantId - Record Id from LWC
     * @return Merchant record
     */
    @AuraEnabled(cacheable=true)
    public static Merchant__c getMerchantDetails(Id merchantId) {
        try {
            return MerchantService.getMerchantDetails(merchantId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Create new merchant from LWC form
     * cacheable=false because it modifies data
     * @param merchant - Merchant record from LWC
     * @return New merchant Id
     */
    @AuraEnabled
    public static Id createMerchant(Merchant__c merchant) {
        try {
            return MerchantService.createMerchant(merchant);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}