@isTest
private class BenefitVerificationControllerTest {

    @TestSetup
    static void makeData(){
        // Create Patient Account
        Account patient = new Account(
            FirstName = 'John',
            LastName = 'Smith',
            Gender__c = 'Male',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert patient;

        // Create Provider Account
        Account provider = new Account(
            Name = 'General Hospital',
            NPI__c = '1234567890',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business').getRecordTypeId()
        );
        insert provider;

        // Create Member Plan
        MemberPlan__c plan = new MemberPlan__c(
            Name = 'Gold Plan',
            PolicyNumber__c = 'POL123',
            GroupNumber__c = 'GRP456',
            SubscriberId__c = 'SUB789'
        );
        insert plan;

        // Create Queues
        Group consultationQueue = new Group(
            Name = 'Consultation_Care_Queue',
            DeveloperName = 'Consultation_Care_Queue',
            Type = 'Queue'
        );
        insert consultationQueue;

        Group infusionQueue = new Group(
            Name = 'Infusion_Care_Queue',
            DeveloperName = 'Infusion_Care_Queue',
            Type = 'Queue'
        );
        insert infusionQueue;

        // Create Queue Members
        List<QueueSobject> queueSObjects = new List<QueueSobject>{
            new QueueSobject(QueueId = consultationQueue.Id, SobjectType = 'CareBenefitVerifyRequest__c'),
            new QueueSobject(QueueId = infusionQueue.Id, SobjectType = 'CareBenefitVerifyRequest__c')
        };
        insert queueSObjects;
    }

    @isTest
    static void testCreateRequestSuccessfully() {
        Account patient = [SELECT Id FROM Account WHERE LastName = 'Smith'];
        Account provider = [SELECT Id FROM Account WHERE Name = 'General Hospital'];
        MemberPlan__c plan = [SELECT Id FROM MemberPlan__c WHERE Name = 'Gold Plan'];

        Test.startTest();
        Id requestId = BenefitVerificationController.createBenefitVerificationRequest(
            patient.Id,
            plan.Id,
            provider.Id,
            'Consultation',
            Date.today(),
            'A01.1',
            '99213'
        );
        Test.stopTest();

        System.assertNotEquals(null, requestId, 'Request ID should not be null.');

        CareBenefitVerifyRequest__c newRequest = [SELECT Id, Status__c, Owner.Name FROM CareBenefitVerifyRequest__c WHERE Id = :requestId];
        System.assertEquals('Submitted', newRequest.Status__c, 'Status should be Submitted.');
        System.assertEquals('Consultation_Care_Queue', newRequest.Owner.Name, 'Request should be assigned to the Consultation queue.');
    }

    @isTest
    static void testMissingRequiredFields() {
        Exception expectedException = null;
        Test.startTest();
        try {
            BenefitVerificationController.createBenefitVerificationRequest(null, null, null, null, null, null, null);
        } catch (AuraHandledException e) {
            expectedException = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, expectedException, 'An exception should have been thrown.');
        System.assert(expectedException.getMessage().contains('required'), 'Error message should indicate required fields are missing.');
    }
}
