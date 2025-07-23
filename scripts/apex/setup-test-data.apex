// Create test accounts
try {
    System.debug('=== Creating Test Data ===');
    
    // Create Patient Account
    System.debug('Creating Patient Account...');
    Account patient = new Account(
        Name = 'John Doe',
        Gender__c = 'Male'
    );
    insert patient;
    System.debug('Created Patient Account: ' + patient.Id);

    // Create Insurance Company (Payer) Account
    System.debug('Creating Payer Account...');
    Account payer = new Account(
        Name = 'Test Insurance Co'
    );
    insert payer;
    System.debug('Created Payer Account: ' + payer.Id);

    // Create Subscriber Account (same as patient for simplicity)
    System.debug('Creating Subscriber Account...');
    Account subscriber = patient; // Use the same account as patient
    System.debug('Using Patient as Subscriber: ' + subscriber.Id);

    // Create Member Plan
    System.debug('Creating Member Plan...');
    MemberPlan__c plan = new MemberPlan__c(
        Name = 'Gold Health Plan',
        GroupNumber__c = 'GRP-001',
        PolicyNumber__c = 'POL-001',
        SubscriberId__c = 'SUB-001',
        MemberNumber__c = 'MEM-001',
        EffectiveFrom__c = Date.today(),
        EffectiveTo__c = Date.today().addYears(1),
        Member__c = patient.Id,
        Payer__c = payer.Id,
        Subscriber__c = patient.Id // Use patient as subscriber
    );
    insert plan;
    System.debug('Created Member Plan: ' + plan.Id);

    // Create Provider Account
    System.debug('Creating Provider Account...');
    Account provider = new Account(
        Name = 'Dr. Jane Smith',
        NPI__c = '1234567890'
    );
    insert provider;
    System.debug('Created Provider Account: ' + provider.Id);

    // Create Care Benefit Verify Request
    System.debug('Creating Benefit Verification Request...');
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
    System.debug('Created Benefit Verification Request: ' + request.Id);

    // Print summary
    System.debug('=== Test Data Creation Complete ===');
    System.debug('Patient/Subscriber ID: ' + patient.Id);
    System.debug('Provider ID: ' + provider.Id);
    System.debug('Payer ID: ' + payer.Id);
    System.debug('Member Plan ID: ' + plan.Id);
    System.debug('Benefit Verify Request ID: ' + request.Id);

} catch(Exception e) {
    System.debug('=== Error Creating Test Data ===');
    System.debug('Error Type: ' + e.getTypeName());
    System.debug('Error Message: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
    
    // If it's a DML error, print more details
    if (e instanceof DmlException) {
        DmlException dmlEx = (DmlException)e;
        for(Integer i = 0; i < dmlEx.getNumDml(); i++) {
            System.debug('DML Error ' + (i+1) + ':');
            System.debug('  Field Names: ' + dmlEx.getDmlFieldNames(i));
            System.debug('  Fields: ' + dmlEx.getDmlFields(i));
            System.debug('  Message: ' + dmlEx.getDmlMessage(i));
        }
    }
} 