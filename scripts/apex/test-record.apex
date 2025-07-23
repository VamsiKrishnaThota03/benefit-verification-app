// Create test record
System.debug('=== Creating Test Record ===');

try {
    // Create test accounts
    Account patient = new Account(
        Name = 'Test Patient',
        Gender__c = 'Male'
    );
    insert patient;
    System.debug('Created Patient Account: ' + patient.Id);
    
    Account payer = new Account(
        Name = 'Test Insurance'
    );
    insert payer;
    System.debug('Created Payer Account: ' + payer.Id);
    
    // Create test member plan
    MemberPlan__c plan = new MemberPlan__c(
        Name = 'Test Plan',
        Member__c = patient.Id,
        Payer__c = payer.Id,
        Subscriber__c = patient.Id,
        MemberNumber__c = 'TEST-001',
        EffectiveFrom__c = Date.today(),
        EffectiveTo__c = Date.today().addYears(1)
    );
    insert plan;
    System.debug('Created Member Plan: ' + plan.Id);
    
    // Query the plan to confirm Member__c
    plan = [SELECT Id, Member__c FROM MemberPlan__c WHERE Id = :plan.Id];
    System.debug('Queried MemberPlan__c.Member__c: ' + plan.Member__c);
    
    // Create test provider
    Account provider = new Account(
        Name = 'Test Provider'
    );
    insert provider;
    System.debug('Created Provider Account: ' + provider.Id);
    
    // Create test HealthCloudGA__Provider__c record (only valid fields)
    HealthCloudGA__Provider__c healthProvider = new HealthCloudGA__Provider__c(
        Name = 'Test Provider',
        healthcloudga__active__c = true
    );
    insert healthProvider;
    System.debug('Created Health Provider: ' + healthProvider.Id);
    
    // Prepare test request
    Id patientId = patient.Id;
    Id planId = plan.Id;
    System.debug('About to insert CareBenefitVerifyRequest__c:');
    System.debug('  Patient__c: ' + patientId);
    System.debug('  MemberPlan__c: ' + planId);
    System.debug('  MemberPlan__r.Member__c: ' + plan.Member__c);
    
    // Create test request
    CareBenefitVerifyRequest__c request = new CareBenefitVerifyRequest__c(
        Patient__c = patientId,
        MemberPlan__c = planId,
        ProviderAccount__c = provider.Id,
        Provider__c = healthProvider.Id,
        ServiceType__c = 'Consultation',
        ServiceDate__c = Date.today(),
        Status__c = 'Submitted'
    );
    
    System.debug('Attempting to insert request...');
    Database.SaveResult result = Database.insert(request, false);
    if(result.isSuccess()) {
        System.debug('Successfully created test record: ' + result.getId());
        
        // Query the record to verify
        CareBenefitVerifyRequest__c verifyRequest = [
            SELECT Id, Patient__c, MemberPlan__c, ProviderAccount__c, ServiceType__c, Status__c,
                   Patient__r.Name, MemberPlan__r.Name, ProviderAccount__r.Name, Provider__c
            FROM CareBenefitVerifyRequest__c
            WHERE Id = :result.getId()
        ];
        System.debug('Verified record:');
        System.debug('  Patient: ' + verifyRequest.Patient__r.Name);
        System.debug('  Member Plan: ' + verifyRequest.MemberPlan__r.Name);
        System.debug('  Provider Account: ' + verifyRequest.ProviderAccount__r.Name);
        System.debug('  Provider: ' + verifyRequest.Provider__c);
        System.debug('  Service Type: ' + verifyRequest.ServiceType__c);
        System.debug('  Status: ' + verifyRequest.Status__c);
    } else {
        System.debug('Failed to create record:');
        for(Database.Error err : result.getErrors()) {
            System.debug('  Error: ' + err.getMessage());
            System.debug('  Fields: ' + err.getFields());
            System.debug('  Status Code: ' + err.getStatusCode());
        }
    }
} catch(Exception e) {
    System.debug('Error creating test record:');
    System.debug('  Type: ' + e.getTypeName());
    System.debug('  Message: ' + e.getMessage());
    if(e instanceof DmlException) {
        DmlException dmlEx = (DmlException)e;
        for(Integer i = 0; i < dmlEx.getNumDml(); i++) {
            System.debug('  DML Error ' + (i+1) + ':');
            System.debug('    Fields: ' + dmlEx.getDmlFields(i));
            System.debug('    Message: ' + dmlEx.getDmlMessage(i));
        }
    }
} 