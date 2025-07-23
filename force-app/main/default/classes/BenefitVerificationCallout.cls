public class BenefitVerificationCallout {

    @future(callout=true)
    public static void sendForVerification(Id careBenefitVerifyRequestId) {
        CareBenefitVerifyRequest__c requestRecord = [
            SELECT Id, Status__c,
                   Patient__r.FirstName, Patient__r.LastName, Patient__r.PersonBirthdate, Patient__r.Gender__c,
                   MemberPlan__r.Name, MemberPlan__r.PolicyNumber__c, MemberPlan__r.GroupNumber__c, MemberPlan__r.SubscriberId__c,
                   ProviderAccount__r.Name, ProviderAccount__r.NPI__c,
                   ServiceType__c, ServiceDate__c, DiagnosisCode__c, ProcedureCode__c,
                   External_API_Status__c, External_API_Status_Reason__c
            FROM CareBenefitVerifyRequest__c
            WHERE Id = :careBenefitVerifyRequestId
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Benefit_Verification_API');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');

        // Split provider name into first and last name if provider exists
        String providerFirstName = '';
        String providerLastName = '';
        if (requestRecord.ProviderAccount__r != null) {
            String[] providerNameParts = requestRecord.ProviderAccount__r.Name.split(' ', 2);
            providerFirstName = providerNameParts[0];
            providerLastName = providerNameParts.size() > 1 ? providerNameParts[1] : '';
        }

        // Construct payload from the SObject
        Map<String, Object> patientDetails = new Map<String, Object>{
            'firstName' => requestRecord.Patient__r.FirstName,
            'lastName' => requestRecord.Patient__r.LastName,
            'dateOfBirth' => requestRecord.Patient__r.PersonBirthdate,
            'gender' => requestRecord.Patient__r.Gender__c
        };
        Map<String, Object> insuranceInfo = new Map<String, Object>{
            'insuranceProviderName' => requestRecord.MemberPlan__r.Name,
            'policyNumber' => requestRecord.MemberPlan__r.PolicyNumber__c,
            'groupNumber' => requestRecord.MemberPlan__r.GroupNumber__c,
            'subscriberId' => requestRecord.MemberPlan__r.SubscriberId__c
        };
        Map<String, Object> providerInfo = new Map<String, Object>{
            'nationalProviderIdentifier' => requestRecord.ProviderAccount__r?.NPI__c,
            'firstName' => providerFirstName,
            'lastName' => providerLastName
        };
        Map<String, Object> serviceDetails = new Map<String, Object>{
            'serviceType' => requestRecord.ServiceType__c,
            'serviceDate' => requestRecord.ServiceDate__c,
            'diagnosisCode' => requestRecord.DiagnosisCode__c,
            'procedureCode' => requestRecord.ProcedureCode__c
        };

        Map<String, Object> payload = new Map<String, Object>{
            'patientDetails' => patientDetails,
            'insuranceInformation' => insuranceInfo,
            'providerInformation' => providerInfo,
            'serviceDetails' => serviceDetails
        };
        
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                BenefitVerificationResponse responseWrapper = (BenefitVerificationResponse) JSON.deserialize(res.getBody(), BenefitVerificationResponse.class);
                requestRecord.External_API_Status__c = responseWrapper.status;
                requestRecord.External_API_Status_Reason__c = responseWrapper.statusReason;
                requestRecord.Status__c = 'In Progress';
            } else {
                requestRecord.External_API_Status__c = 'API Error';
                requestRecord.External_API_Status_Reason__c = 'API Error: ' + res.getStatusCode() + ' ' + res.getStatus() + ' - ' + res.getBody();
                requestRecord.Status__c = 'Error';
            }
        } catch (Exception e) {
            requestRecord.External_API_Status__c = 'System Error';
            requestRecord.External_API_Status_Reason__c = e.getMessage();
            requestRecord.Status__c = 'Error';
        }

        update requestRecord;
    }
}
