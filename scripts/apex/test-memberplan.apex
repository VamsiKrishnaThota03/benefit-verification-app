// Create test accounts (all business accounts for now)
Account member = new Account(
    Name = 'John Doe'
);
insert member;

Account payer = new Account(
    Name = 'Test Insurance Co'
);
insert payer;

Account subscriber = new Account(
    Name = 'Jane Doe'
);
insert subscriber;

// Create a Member Plan with all required fields
try {
    MemberPlan__c plan = new MemberPlan__c(
        Name = 'Test Plan',
        GroupNumber__c = 'TEST-GRP-001',
        PolicyNumber__c = 'TEST-POL-001',
        SubscriberId__c = 'TEST-SUB-001',
        MemberNumber__c = 'TEST-MEM-001',
        EffectiveFrom__c = Date.today(),
        EffectiveTo__c = Date.today().addYears(1),
        Member__c = member.Id,
        Payer__c = payer.Id,
        Subscriber__c = subscriber.Id
    );
    insert plan;
    System.debug('Success! Plan ID: ' + plan.Id);
} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
} 