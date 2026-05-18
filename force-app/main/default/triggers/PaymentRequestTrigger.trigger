/**
 * @description Trigger for Payment_Request__c object.
 * Contains ZERO business logic.
 * All logic delegated to PaymentRequestTriggerHandler.
 * One trigger per object — industry standard.
 */
trigger PaymentRequestTrigger on Payment_Request__c (
    before insert,
    before update,
    after insert,
    after update
) {
    PaymentRequestTriggerHandler handler =
        new PaymentRequestTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.onBeforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            handler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.onAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            handler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}