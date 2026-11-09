/**
 * Logic for CareBenefitVerifyRequestTrigger.
 *
 * before insert: route each request to the queue for its service type
 *                (Consultation/Infusion/Surgery -> <Type>_Care_Queue).
 * after insert:  send every request with status Submitted to the external
 *                verification API (see BenefitVerificationCallout).
 */
public without sharing class CareBenefitVerifyRequestTriggerHandler {

    public static final Map<String, String> QUEUE_BY_SERVICE_TYPE = new Map<String, String>{
        'Consultation' => 'Consultation_Care_Queue',
        'Infusion' => 'Infusion_Care_Queue',
        'Surgery' => 'Surgery_Care_Queue'
    };

    public static void beforeInsert(List<CareBenefitVerifyRequest__c> requests) {
        Map<String, Id> queueIdByName = new Map<String, Id>();
        for (Group queue : [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName IN :QUEUE_BY_SERVICE_TYPE.values()
        ]) {
            queueIdByName.put(queue.DeveloperName, queue.Id);
        }

        for (CareBenefitVerifyRequest__c request : requests) {
            String queueName = QUEUE_BY_SERVICE_TYPE.get(request.ServiceType__c);
            if (queueName == null) {
                continue; // e.g. "Other": stays with the creator
            }
            Id queueId = queueIdByName.get(queueName);
            if (queueId != null) {
                request.OwnerId = queueId;
            } else {
                System.debug(LoggingLevel.WARN, 'Queue ' + queueName + ' not found; request stays with its creator.');
            }
        }
    }

    public static void afterInsert(List<CareBenefitVerifyRequest__c> requests) {
        List<Id> submitted = new List<Id>();
        for (CareBenefitVerifyRequest__c request : requests) {
            if (request.Status__c == 'Submitted') {
                submitted.add(request.Id);
            }
        }
        if (submitted.isEmpty()) {
            return;
        }
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            // Exceeding the limit would throw an uncatchable LimitException and roll back the insert.
            System.debug(LoggingLevel.ERROR, 'Queueable limit reached; ' + submitted.size()
                + ' request(s) were saved but not sent for verification: ' + submitted);
            return;
        }
        BenefitVerificationCallout.enqueue(submitted);
    }
}
