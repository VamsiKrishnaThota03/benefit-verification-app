trigger CareBenefitVerifyRequestTrigger on CareBenefitVerifyRequest__c (before insert, after insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CareBenefitVerifyRequestTriggerHandler.beforeInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        CareBenefitVerifyRequestTriggerHandler.afterInsert(Trigger.new);
    }
}
