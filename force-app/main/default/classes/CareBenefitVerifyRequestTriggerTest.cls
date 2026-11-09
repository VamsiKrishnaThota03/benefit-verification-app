@isTest
private class CareBenefitVerifyRequestTriggerTest {

    @TestSetup
    static void makeData() {
        BenefitVerificationTestData.createFixture();
    }

    private static Map<String, SObject> fixture() {
        return new Map<String, SObject>{
            'patient' => [SELECT Id FROM Account WHERE LastName = 'Doe'],
            'provider' => [SELECT Id FROM Account WHERE Name = 'John Smith MD'],
            'plan' => [SELECT Id FROM MemberPlan__c LIMIT 1]
        };
    }

    @isTest
    static void routesByServiceTypeAndSendsSubmittedRequests() {
        Map<String, Id> queues = BenefitVerificationTestData.careQueues();
        Map<String, SObject> fx = fixture();
        Account patient = (Account) fx.get('patient');
        MemberPlan__c plan = (MemberPlan__c) fx.get('plan');
        Account provider = (Account) fx.get('provider');

        List<CareBenefitVerifyRequest__c> requests = new List<CareBenefitVerifyRequest__c>();
        for (String type : new List<String>{ 'Consultation', 'Infusion', 'Surgery', 'Other' }) {
            requests.add(BenefitVerificationTestData.newRequest(patient, plan, provider, type, 'Submitted'));
        }
        Test.setMock(HttpCalloutMock.class, new BenefitVerificationTestData.MockResponse(200,
            new Map<String, Object>{ 'status' => 'Acknowledged', 'statusReason' => 'OK' }));

        Test.startTest();
        insert requests;
        Test.stopTest();

        for (CareBenefitVerifyRequest__c r : [
            SELECT ServiceType__c, OwnerId, Status__c, External_API_Status__c FROM CareBenefitVerifyRequest__c
        ]) {
            String queueName = CareBenefitVerifyRequestTriggerHandler.QUEUE_BY_SERVICE_TYPE.get(r.ServiceType__c);
            Id expectedOwner = queueName == null ? UserInfo.getUserId() : queues.get(queueName);
            System.assertEquals(expectedOwner, r.OwnerId, 'Unexpected owner for ' + r.ServiceType__c);
            System.assertEquals('In Progress', r.Status__c, 'Submitted requests should be sent: ' + r.ServiceType__c);
            System.assertEquals('Acknowledged', r.External_API_Status__c);
        }
    }

    @isTest
    static void requestsNotSubmittedAreNotSent() {
        Map<String, SObject> fx = fixture();
        CareBenefitVerifyRequest__c request = BenefitVerificationTestData.newRequest(
            (Account) fx.get('patient'), (MemberPlan__c) fx.get('plan'), null, 'Other', 'In Progress');

        Test.startTest();
        insert request;
        System.assertEquals(0, Limits.getQueueableJobs(), 'No verification job should be queued.');
        Test.stopTest();

        CareBenefitVerifyRequest__c saved = [
            SELECT Status__c, External_API_Status__c FROM CareBenefitVerifyRequest__c WHERE Id = :request.Id
        ];
        System.assertEquals('In Progress', saved.Status__c);
        System.assertEquals(null, saved.External_API_Status__c);
    }
}
