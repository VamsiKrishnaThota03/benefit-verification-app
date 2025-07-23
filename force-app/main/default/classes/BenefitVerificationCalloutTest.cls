@isTest
private class BenefitVerificationCalloutTest {

    @TestSetup
    static void makeData(){
        // Create Patient Account with Gender
        Account patient = new Account(
            FirstName = 'Jane',
            LastName = 'Doe',
            Gender__c = 'Female',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert patient;

        // Create Provider Account with full name
        Account provider = new Account(
            Name = 'John Smith MD',
            NPI__c = '1234567890',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business').getRecordTypeId()
        );
        insert provider;

        MemberPlan__c plan = new MemberPlan__c(
            Name = 'Silver Plan',
            PolicyNumber__c = 'POL123',
            GroupNumber__c = 'GRP456',
            SubscriberId__c = 'SUB789'
        );
        insert plan;

        CareBenefitVerifyRequest__c request = new CareBenefitVerifyRequest__c(
            Patient__c = patient.Id,
            ProviderAccount__c = provider.Id,
            MemberPlan__c = plan.Id,
            ServiceType__c = 'Consultation',
            ServiceDate__c = Date.today(),
            DiagnosisCode__c = 'A01.1',
            ProcedureCode__c = '99213',
            Status__c = 'Submitted'
        );
        insert request;
    }

    @isTest
    static void testSuccessfulCallout() {
        CareBenefitVerifyRequest__c request = [SELECT Id FROM CareBenefitVerifyRequest__c LIMIT 1];

        // Set up the mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Acknowledged', 'Request received.'));

        Test.startTest();
        BenefitVerificationCallout.sendForVerification(request.Id);
        Test.stopTest();

        // Verify the record was updated correctly
        CareBenefitVerifyRequest__c updatedRequest = [
            SELECT Id, Status__c, External_API_Status__c, External_API_Status_Reason__c 
            FROM CareBenefitVerifyRequest__c 
            WHERE Id = :request.Id
        ];
        System.assertEquals('In Progress', updatedRequest.Status__c);
        System.assertEquals('Acknowledged', updatedRequest.External_API_Status__c);
        System.assertEquals('Request received.', updatedRequest.External_API_Status_Reason__c);
    }

    @isTest
    static void testFailedCallout() {
        CareBenefitVerifyRequest__c request = [SELECT Id FROM CareBenefitVerifyRequest__c LIMIT 1];

        // Set up the mock error response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Server Error', 'Internal server error.'));

        Test.startTest();
        BenefitVerificationCallout.sendForVerification(request.Id);
        Test.stopTest();

        // Verify the record was updated correctly
        CareBenefitVerifyRequest__c updatedRequest = [
            SELECT Id, Status__c, External_API_Status__c 
            FROM CareBenefitVerifyRequest__c 
            WHERE Id = :request.Id
        ];
        System.assertEquals('Error', updatedRequest.Status__c);
        System.assertEquals('API Error', updatedRequest.External_API_Status__c);
    }

    // Helper class for mock responses
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String statusReason;

        public MockHttpResponseGenerator(Integer code, String stat, String reason) {
            this.statusCode = code;
            this.status = stat;
            this.statusReason = reason;
        }

        public HttpResponse respond(HttpRequest req) {
            // Verify the request payload contains all required fields
            Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(req.getBody());
            Map<String, Object> patientDetails = (Map<String, Object>)requestBody.get('patientDetails');
            Map<String, Object> providerInfo = (Map<String, Object>)requestBody.get('providerInformation');
            
            // Assert patient gender is included
            System.assertNotEquals(null, patientDetails.get('gender'), 'Gender should be included in patient details');
            
            // Assert provider name is split correctly
            System.assertNotEquals(null, providerInfo.get('firstName'), 'Provider first name should be included');
            System.assertNotEquals(null, providerInfo.get('lastName'), 'Provider last name should be included');

            String responseBody = JSON.serialize(new Map<String, String>{
                'status' => this.status,
                'statusReason' => this.statusReason
            });

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }
}
