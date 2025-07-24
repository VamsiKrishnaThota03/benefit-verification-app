@isTest
private class CareBenefitVerifyRequestTriggerTest {
    @isTest
    static void testTriggerCallsCallout() {
        // Create test data
        Account patient = new Account(Name = 'Test Patient');
        insert patient;
        MemberPlan__c plan = new MemberPlan__c(Name = 'Test Plan', GroupNumber__c = 'G1', PolicyNumber__c = 'P1', SubscriberId__c = 'S1', Member__c = patient.Id, Payer__c = patient.Id, Subscriber__c = patient.Id, MemberNumber__c = 'M1', EffectiveFrom__c = Date.today(), EffectiveTo__c = Date.today().addYears(1));
        insert plan;
        // Set up mock callout
        Test.setMock(HttpCalloutMock.class, new CareBenefitVerifyRequestTriggerTest.MockHttpResponseGenerator());
        Test.startTest();
        CareBenefitVerifyRequest__c req = new CareBenefitVerifyRequest__c(
            Patient__c = patient.Id,
            MemberPlan__c = plan.Id,
            ServiceType__c = 'Consultation',
            ServiceDate__c = Date.today(),
            Status__c = 'Submitted'
        );
        insert req;
        Test.stopTest();
        // After trigger, the callout should have run and updated the record
        CareBenefitVerifyRequest__c updated = [SELECT Id, External_API_Status__c FROM CareBenefitVerifyRequest__c WHERE Id = :req.Id];
        System.assertNotEquals(null, updated.External_API_Status__c, 'External API Status should be set by callout');
    }
    // Simple mock for callout
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"Acknowledged","statusReason":"Test Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
} 