public with sharing class BenefitVerificationController {

    @AuraEnabled
    public static Id createBenefitVerificationRequest(String patientId, String memberPlanId, String providerId, String serviceType, Date serviceDate, String diagnosisCode, String procedureCode) {
        if (String.isBlank(patientId) || String.isBlank(memberPlanId) || String.isBlank(serviceType)) {
            throw new AuraHandledException('Patient, Member Plan, and Service Type are required.');
        }

        try {
            // Querying for existence and to ensure IDs are valid
            Account patient = [SELECT Id FROM Account WHERE Id = :patientId];
            MemberPlan__c plan = [SELECT Id FROM MemberPlan__c WHERE Id = :memberPlanId];
            Account provider;
            if (String.isNotBlank(providerId)) {
                provider = [SELECT Id FROM Account WHERE Id = :providerId];
            }

            CareBenefitVerifyRequest__c request = new CareBenefitVerifyRequest__c(
                Patient__c = patient.Id,
                MemberPlan__c = plan.Id,
                ProviderAccount__c = provider?.Id,
                ServiceType__c = serviceType,
                ServiceDate__c = serviceDate,
                DiagnosisCode__c = diagnosisCode,
                ProcedureCode__c = procedureCode,
                Status__c = 'Submitted'
            );

            insert request;

            // Assign to Queue based on Service Type
            assignToQueue(request.Id, serviceType);

            // Asynchronously send to external API
            // This is done in a future method to avoid delaying the UI and to respect callout limits
            BenefitVerificationCallout.sendForVerification(request.Id);

            return request.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating request: ' + e.getMessage());
        }
    }

    @TestVisible
    private static void assignToQueue(Id requestId, String serviceType) {
        String queueName = '';
        if (serviceType == 'Consultation') {
            queueName = 'Consultation_Verification_Queue';
        } else if (serviceType == 'Infusion') {
            queueName = 'Infusion_Verification_Queue';
        } else if (serviceType == 'Surgery') {
            queueName = 'Surgery_Verification_Queue';
        } else {
            // If no matching service type, do not assign to a queue.
            // It will remain owned by the creator.
            return;
        }

        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :queueName LIMIT 1];
        if (queue != null) {
            List<CareBenefitVerifyRequest__c> requestsToUpdate = new List<CareBenefitVerifyRequest__c>{
                new CareBenefitVerifyRequest__c(Id = requestId, OwnerId = queue.Id)
            };
            update requestsToUpdate;
        }
    }
}
