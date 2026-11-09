@isTest
private class BenefitVerificationControllerTest {

    @TestSetup
    static void makeData() {
        BenefitVerificationTestData.createFixture();
    }

    @isTest
    static void createsRequestRoutesItAndSendsIt() {
        Map<String, Id> queues = BenefitVerificationTestData.careQueues();
        Account patient = [SELECT Id FROM Account WHERE LastName = 'Doe'];
        Account provider = [SELECT Id FROM Account WHERE Name = 'John Smith MD'];
        MemberPlan__c plan = [SELECT Id FROM MemberPlan__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new BenefitVerificationTestData.MockResponse(200,
            new Map<String, Object>{ 'status' => 'Acknowledged', 'statusReason' => 'OK' }));

        Test.startTest();
        Id requestId = BenefitVerificationController.createBenefitVerificationRequest(
            patient.Id, plan.Id, provider.Id, 'Consultation', Date.today(), 'A01.1', '99213');
        Test.stopTest();

        CareBenefitVerifyRequest__c created = [
            SELECT Status__c, OwnerId, External_API_Status__c FROM CareBenefitVerifyRequest__c WHERE Id = :requestId
        ];
        System.assertEquals(queues.get('Consultation_Care_Queue'), created.OwnerId,
            'Request should be routed to the Consultation care queue.');
        System.assertEquals('In Progress', created.Status__c, 'Callout should have run once and acknowledged.');
        System.assertEquals('Acknowledged', created.External_API_Status__c);
    }

    @isTest
    static void missingRequiredFieldsThrows() {
        String message;
        try {
            BenefitVerificationController.createBenefitVerificationRequest(null, null, null, null, null, null, null);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertNotEquals(null, message, 'An exception should have been thrown.');
        System.assert(message.contains('required'), message);
    }

    @isTest
    static void invalidIdThrows() {
        String message;
        try {
            BenefitVerificationController.createBenefitVerificationRequest(
                'not-an-id', 'also-not-an-id', null, 'Consultation', Date.today(), null, null);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertNotEquals(null, message);
        System.assert(message.startsWith('Invalid record Id'), message);
    }

    @isTest
    static void planOfAnotherPatientIsRejected() {
        MemberPlan__c plan = [SELECT Id FROM MemberPlan__c LIMIT 1];
        Account otherPatient = BenefitVerificationTestData.createPatient('Other', 'Person');

        String message;
        try {
            BenefitVerificationController.createBenefitVerificationRequest(
                otherPatient.Id, plan.Id, null, 'Other', Date.today(), null, null);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertNotEquals(null, message, 'The ValidMemberPlan rule should reject the request.');
        System.assert(message.startsWith('Could not create the request'), message);
    }
}
