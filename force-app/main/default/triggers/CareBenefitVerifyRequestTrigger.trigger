// Ensuring deployment for CareBenefitVerifyRequest__c trigger
trigger CareBenefitVerifyRequestTrigger on CareBenefitVerifyRequest__c (after insert, after update) {
    List<Id> newRequestIds = new List<Id>();
    for (CareBenefitVerifyRequest__c req : Trigger.new) {
        CareBenefitVerifyRequest__c oldReq = Trigger.isInsert ? null : Trigger.oldMap.get(req.Id);
        Boolean wasNotSubmitted = Trigger.isInsert ? true : (oldReq.Status__c == null || oldReq.Status__c.trim().toLowerCase() != 'submitted');
        System.debug('Trigger fired for: ' + req.Id + ' with Status: ' + req.Status__c);
        if (
            req.Status__c != null &&
            req.Status__c.trim().toLowerCase() == 'submitted' &&
            wasNotSubmitted
        ) {
            newRequestIds.add(req.Id);
        }
    }
    if (!newRequestIds.isEmpty()) {
        System.debug('Calling BenefitVerificationCallout for: ' + newRequestIds);
        for (Id reqId : newRequestIds) {
            BenefitVerificationCallout.sendForVerification(reqId);
        }
    }
} 