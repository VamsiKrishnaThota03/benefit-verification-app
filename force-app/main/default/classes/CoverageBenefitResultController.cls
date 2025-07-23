@RestResource(urlMapping='/care-benefit-verification-results/v1/*')
global with sharing class CoverageBenefitResultController {

    @HttpPost
    global static void createCoverageBenefit() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String requestBody = req.requestBody.toString();
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            String careBenefitVerifyRequestId = (String) body.get('careBenefitVerifyRequestId');
            if (String.isBlank(careBenefitVerifyRequestId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{'error' => 'careBenefitVerifyRequestId is required.'}));
                return;
            }

            // Mocked benefit data
            String benefitStatus = (String) body.get('benefitStatus');
            Decimal copay = (Decimal) body.get('copay');
            Decimal deductible = (Decimal) body.get('deductible');
            Boolean isCovered = (Boolean) body.get('isCovered');

            CareBenefitVerifyRequest__c cbvr = [SELECT Id, Patient__c, MemberPlan__c FROM CareBenefitVerifyRequest__c WHERE Id = :careBenefitVerifyRequestId];

            CoverageBenefit__c benefit = new CoverageBenefit__c(
                CareBenefitVerifyRequest__c = cbvr.Id,
                Patient__c = cbvr.Patient__c,
                MemberPlan__c = cbvr.MemberPlan__c,
                BenefitStatus__c = benefitStatus,
                CopayAmount__c = copay,
                DeductibleAmount__c = deductible,
                IsCovered__c = isCovered,
                VerificationDate__c = System.now()
            );

            insert benefit;

            // Update original request to show it's completed
            cbvr.Status__c = 'Completed';
            update cbvr;

            res.statusCode = 201; // Created
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{'coverageBenefitId' => benefit.Id}));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{'error' => e.getMessage(), 'stacktrace' => e.getStackTraceString()}));
        }
    }
}
