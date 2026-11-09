@isTest
private class BenefitVerificationCalloutTest {

    @TestSetup
    static void makeData() {
        Map<String, SObject> fx = BenefitVerificationTestData.createFixture();
        // Status "In Progress" so the trigger does not enqueue its own callout.
        insert BenefitVerificationTestData.newRequest(
            (Account) fx.get('patient'), (MemberPlan__c) fx.get('plan'), (Account) fx.get('provider'),
            'Consultation', 'In Progress');
    }

    private static CareBenefitVerifyRequest__c runJob(HttpCalloutMock mock) {
        CareBenefitVerifyRequest__c request = [SELECT Id FROM CareBenefitVerifyRequest__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.enqueueJob(new BenefitVerificationCallout.Job(new List<Id>{ request.Id }));
        Test.stopTest();
        return [
            SELECT Id, Status__c, External_API_Status__c, External_API_Status_Reason__c
            FROM CareBenefitVerifyRequest__c WHERE Id = :request.Id
        ];
    }

    @isTest
    static void acknowledgedResponseMovesRequestToInProgress() {
        CareBenefitVerifyRequest__c updated = runJob(new BenefitVerificationTestData.MockResponse(200,
            new Map<String, Object>{ 'status' => 'Acknowledged', 'statusReason' => 'Request received.' }));

        System.assertEquals('In Progress', updated.Status__c);
        System.assertEquals('Acknowledged', updated.External_API_Status__c);
        System.assertEquals('Request received.', updated.External_API_Status_Reason__c);
        System.assertEquals(0, [SELECT COUNT() FROM CoverageBenefit__c],
            'No coverage benefit should be invented when the API only acknowledges the request.');
    }

    @isTest
    static void responseWithBenefitDetailsCreatesCoverageBenefit() {
        CareBenefitVerifyRequest__c updated = runJob(new BenefitVerificationTestData.MockResponse(200,
            new Map<String, Object>{
                'status' => 'Verified', 'statusReason' => 'Coverage found.',
                'benefitStatus' => 'Active', 'copay' => 40, 'deductible' => 750.50, 'isCovered' => true
            }));

        System.assertEquals('Completed', updated.Status__c);
        CoverageBenefit__c benefit = [
            SELECT BenefitStatus__c, CopayAmount__c, DeductibleAmount__c, IsCovered__c, CareBenefitVerifyRequest__c
            FROM CoverageBenefit__c
        ];
        System.assertEquals(updated.Id, benefit.CareBenefitVerifyRequest__c);
        System.assertEquals('Active', benefit.BenefitStatus__c);
        System.assertEquals(40, benefit.CopayAmount__c);
        System.assertEquals(750.50, benefit.DeductibleAmount__c);
        System.assertEquals(true, benefit.IsCovered__c);
    }

    @isTest
    static void httpErrorMarksRequestAsError() {
        CareBenefitVerifyRequest__c updated = runJob(
            new BenefitVerificationTestData.MockResponse(500, '{"message":"Internal server error"}'));

        System.assertEquals('Error', updated.Status__c);
        System.assertEquals('API Error', updated.External_API_Status__c);
        System.assert(updated.External_API_Status_Reason__c.contains('HTTP 500'), updated.External_API_Status_Reason__c);
    }

    @isTest
    static void calloutExceptionMarksRequestAsError() {
        CareBenefitVerifyRequest__c updated = runJob(new BenefitVerificationTestData.FailingMock());

        System.assertEquals('Error', updated.Status__c);
        System.assertEquals('System Error', updated.External_API_Status__c);
        System.assert(updated.External_API_Status_Reason__c.contains('Read timed out'));
    }

    @isTest
    static void unparseableResponseMarksRequestAsError() {
        CareBenefitVerifyRequest__c updated = runJob(new BenefitVerificationTestData.MockResponse(200, 'not json'));

        System.assertEquals('Error', updated.Status__c);
        System.assertEquals('Invalid Response', updated.External_API_Status__c);
    }

    @isTest
    static void payloadContainsPatientInsuranceProviderAndService() {
        CareBenefitVerifyRequest__c request = [
            SELECT Id, Patient__r.FirstName, Patient__r.LastName, Patient__r.PersonBirthdate, Patient__r.Gender__c,
                   MemberPlan__r.Name, MemberPlan__r.PolicyNumber__c, MemberPlan__r.GroupNumber__c,
                   MemberPlan__r.SubscriberId__c, ProviderAccount__r.Name, ProviderAccount__r.NPI__c,
                   ServiceType__c, ServiceDate__c, DiagnosisCode__c, ProcedureCode__c
            FROM CareBenefitVerifyRequest__c LIMIT 1
        ];

        Map<String, Object> payload = BenefitVerificationCallout.buildPayload(request);
        Map<String, Object> patient = (Map<String, Object>) payload.get('patientDetails');
        Map<String, Object> insurance = (Map<String, Object>) payload.get('insuranceInformation');
        Map<String, Object> provider = (Map<String, Object>) payload.get('providerInformation');
        Map<String, Object> service = (Map<String, Object>) payload.get('serviceDetails');

        System.assertEquals('Jane', patient.get('firstName'));
        System.assertEquals('Female', patient.get('gender'));
        System.assertEquals('POL123', insurance.get('policyNumber'));
        System.assertEquals('John', provider.get('firstName'));
        System.assertEquals('Smith MD', provider.get('lastName'));
        System.assertEquals('1234567890', provider.get('nationalProviderIdentifier'));
        System.assertEquals('Consultation', service.get('serviceType'));
    }

    @isTest
    static void truncateRespectsLimit() {
        System.assertEquals(null, BenefitVerificationCallout.truncate(null, 5));
        System.assertEquals('abc', BenefitVerificationCallout.truncate('abc', 5));
        System.assertEquals('abcde', BenefitVerificationCallout.truncate('abcdefgh', 5));
    }
}
