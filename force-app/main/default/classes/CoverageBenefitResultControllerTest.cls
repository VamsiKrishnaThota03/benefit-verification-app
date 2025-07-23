@isTest
private class CoverageBenefitResultControllerTest {

    @TestSetup
    static void makeData(){
        Account patient = new Account(
            FirstName = 'Test',
            LastName = 'Patient',
            Gender__c = 'Female',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert patient;

        MemberPlan__c plan = new MemberPlan__c(
            Name = 'Test Plan',
            PolicyNumber__c = 'POL123',
            GroupNumber__c = 'GRP456',
            SubscriberId__c = 'SUB789'
        );
        insert plan;

        CareBenefitVerifyRequest__c request = new CareBenefitVerifyRequest__c(
            Patient__c = patient.Id,
            MemberPlan__c = plan.Id,
            Status__c = 'In Progress'
        );
        insert request;
    }

    @isTest
    static void testPostRequestSuccess() {
        CareBenefitVerifyRequest__c request = [SELECT Id FROM CareBenefitVerifyRequest__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/care-benefit-verification-results/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'careBenefitVerifyRequestId' => request.Id,
            'benefitStatus' => 'Active',
            'copay' => 50.0,
            'deductible' => 1000.0,
            'isCovered' => true
        }));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CoverageBenefitResultController.createCoverageBenefit();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Response status code should be 201 (Created).');

        CareBenefitVerifyRequest__c updatedRequest = [SELECT Status__c FROM CareBenefitVerifyRequest__c WHERE Id = :request.Id];
        System.assertEquals('Completed', updatedRequest.Status__c, 'Request status should be updated to Completed.');

        List<CoverageBenefit__c> benefits = [SELECT Id FROM CoverageBenefit__c WHERE CareBenefitVerifyRequest__c = :request.Id];
        System.assertEquals(1, benefits.size(), 'A CoverageBenefit record should have been created.');
    }

    @isTest
    static void testPostRequestFailure() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/care-benefit-verification-results/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"careBenefitVerifyRequestId": "INVALID_ID"}');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CoverageBenefitResultController.createCoverageBenefit();
        Test.stopTest();

        System.assertEquals(500, res.statusCode, 'Response status code should be 500 for an invalid ID.');
    }
}

