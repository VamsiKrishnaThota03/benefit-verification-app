@isTest
private class CoverageBenefitResultControllerTest {

    @TestSetup
    static void makeData() {
        Map<String, SObject> fx = BenefitVerificationTestData.createFixture();
        insert BenefitVerificationTestData.newRequest(
            (Account) fx.get('patient'), (MemberPlan__c) fx.get('plan'), null, 'Other', 'In Progress');
    }

    private static RestResponse post(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/care-benefit-verification-results/v1/';
        req.httpMethod = 'POST';
        req.requestBody = body == null ? null : Blob.valueOf(body);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        CoverageBenefitResultController.createCoverageBenefit();
        return res;
    }

    private static String payload(Object requestId, Map<String, Object> extra) {
        Map<String, Object> body = new Map<String, Object>{
            'careBenefitVerifyRequestId' => requestId,
            'benefitStatus' => 'Active',
            'copay' => 50.0,
            'deductible' => 1000,
            'isCovered' => true
        };
        if (extra != null) {
            body.putAll(extra);
        }
        return JSON.serialize(body);
    }

    @isTest
    static void createsBenefitAndCompletesRequest() {
        CareBenefitVerifyRequest__c request = [SELECT Id FROM CareBenefitVerifyRequest__c LIMIT 1];

        Test.startTest();
        RestResponse res = post(payload(request.Id, null));
        Test.stopTest();

        System.assertEquals(201, res.statusCode, res.responseBody.toString());
        System.assertEquals('Completed', [SELECT Status__c FROM CareBenefitVerifyRequest__c WHERE Id = :request.Id].Status__c);
        CoverageBenefit__c benefit = [SELECT CopayAmount__c, DeductibleAmount__c, IsCovered__c FROM CoverageBenefit__c];
        System.assertEquals(50, benefit.CopayAmount__c);
        System.assertEquals(1000, benefit.DeductibleAmount__c);
        System.assertEquals(true, benefit.IsCovered__c);
    }

    @isTest
    static void rejectsMissingId() {
        RestResponse res = post(payload(null, null));
        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void rejectsMalformedId() {
        RestResponse res = post(payload('INVALID_ID', null));
        System.assertEquals(400, res.statusCode);
        System.assert(!res.responseBody.toString().contains('stacktrace'), 'Stack traces must not be returned.');
    }

    @isTest
    static void returns404ForUnknownRequest() {
        String prefix = CareBenefitVerifyRequest__c.SObjectType.getDescribe().getKeyPrefix();
        RestResponse res = post(payload(prefix + '000000000000', null));
        System.assertEquals(404, res.statusCode);
    }

    @isTest
    static void rejectsInvalidJsonAndTypes() {
        System.assertEquals(400, post('{not json').statusCode);
        System.assertEquals(400, post('[1,2]').statusCode);
        CareBenefitVerifyRequest__c request = [SELECT Id FROM CareBenefitVerifyRequest__c LIMIT 1];
        System.assertEquals(400, post(payload(request.Id, new Map<String, Object>{ 'copay' => 'fifty' })).statusCode);
        System.assertEquals(400, post(payload(request.Id, new Map<String, Object>{ 'benefitStatus' => '' })).statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM CoverageBenefit__c]);
    }
}
