/**
 * Apex entry point for creating a Care Benefit Verification Request from
 * Lightning components or other Apex. Queue routing and the verification
 * callout are handled by CareBenefitVerifyRequestTrigger, so requests created
 * here follow exactly the same path as those created by the LWC form.
 */
public with sharing class BenefitVerificationController {

    @AuraEnabled
    public static Id createBenefitVerificationRequest(
        String patientId, String memberPlanId, String providerId, String serviceType,
        Date serviceDate, String diagnosisCode, String procedureCode
    ) {
        if (String.isBlank(patientId) || String.isBlank(memberPlanId)
                || String.isBlank(serviceType) || serviceDate == null) {
            throw auraError('Patient, Member Plan, Service Type and Service Date are required.');
        }

        CareBenefitVerifyRequest__c request;
        try {
            request = new CareBenefitVerifyRequest__c(
                Patient__c = Id.valueOf(patientId),
                MemberPlan__c = Id.valueOf(memberPlanId),
                ProviderAccount__c = String.isBlank(providerId) ? null : Id.valueOf(providerId),
                ServiceType__c = serviceType,
                ServiceDate__c = serviceDate,
                DiagnosisCode__c = diagnosisCode,
                ProcedureCode__c = procedureCode,
                Status__c = 'Submitted'
            );
        } catch (StringException e) {
            throw auraError('Invalid record Id: ' + e.getMessage());
        }

        if (!Schema.SObjectType.CareBenefitVerifyRequest__c.isCreateable()) {
            throw auraError('You do not have permission to create benefit verification requests.');
        }
        Database.SaveResult result = Database.insert(request, false);
        if (!result.isSuccess()) {
            List<String> messages = new List<String>();
            for (Database.Error error : result.getErrors()) {
                messages.add(error.getMessage());
            }
            throw auraError('Could not create the request: ' + String.join(messages, '; '));
        }
        return result.getId();
    }

    /** AuraHandledException whose message is also visible to Apex callers and tests. */
    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
