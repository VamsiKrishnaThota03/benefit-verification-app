trigger CareBenefitVerifyRequestTrigger on CareBenefitVerifyRequest__c (before insert, after insert) {
    // --- BEFORE INSERT: Assign to queue based on Service Type ---
    if (Trigger.isBefore && Trigger.isInsert) {
        Map<String, String> serviceTypeToQueue = new Map<String, String>{
            'Consultation' => 'Consultation_Care_Queue',
            'Infusion'     => 'Infusion_Care_Queue',
            'Surgery'      => 'Surgery_Care_Queue'
        };

        // Query all queues once for efficiency
        Map<String, Id> queueNameToId = new Map<String, Id>();
        for (Group g : [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName IN :serviceTypeToQueue.values()
        ]) {
            queueNameToId.put(g.DeveloperName, g.Id);
        }

        for (CareBenefitVerifyRequest__c req : Trigger.new) {
            String queueName = serviceTypeToQueue.get(req.ServiceType__c);
            if (queueName != null && queueNameToId.containsKey(queueName)) {
                req.OwnerId = queueNameToId.get(queueName);
            }
        }
    }

    // --- AFTER INSERT: Trigger API callout for 'Submitted' status ---
    if (Trigger.isAfter && Trigger.isInsert) {
        List<Id> newRequestIds = new List<Id>();
        for (CareBenefitVerifyRequest__c req : Trigger.new) {
            if (req.Status__c != null && req.Status__c.trim().toLowerCase() == 'submitted') {
                newRequestIds.add(req.Id);
            }
        }
        if (!newRequestIds.isEmpty()) {
            for (Id reqId : newRequestIds) {
                BenefitVerificationCallout.sendForVerification(reqId);
            }
        }
    }
} 