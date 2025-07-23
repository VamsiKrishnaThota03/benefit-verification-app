// Check validation rules on CareBenefitVerifyRequest__c
System.debug('=== Checking Validation Rules ===');

// Get the describe result for CareBenefitVerifyRequest__c
Schema.DescribeSObjectResult describeResult = CareBenefitVerifyRequest__c.SObjectType.getDescribe();

// Check fields
Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
for(String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    if(field.getReferenceTo().size() > 0) {
        System.debug(fieldName + ':');
        System.debug('  References: ' + field.getReferenceTo());
        System.debug('  Required: ' + !field.isNillable());
        System.debug('---');
    }
}

// Query for validation rules
List<CareBenefitVerifyRequest__c> requests = [
    SELECT Id, Patient__c, MemberPlan__c, ProviderAccount__c, ServiceType__c, Status__c,
           Patient__r.Name, MemberPlan__r.Name, MemberPlan__r.Member__c, ProviderAccount__r.Name,
           Provider__c
    FROM CareBenefitVerifyRequest__c
    LIMIT 1
];

if(!requests.isEmpty()) {
    CareBenefitVerifyRequest__c request = requests[0];
    System.debug('Found existing record:');
    System.debug('  Patient: ' + request.Patient__r.Name);
    System.debug('  Member Plan: ' + request.MemberPlan__r.Name);
    System.debug('  Member Plan Member: ' + request.MemberPlan__r.Member__c);
    System.debug('  Provider: ' + request.ProviderAccount__r.Name);
    System.debug('  Provider__c: ' + request.Provider__c);
    System.debug('  Service Type: ' + request.ServiceType__c);
    System.debug('  Status: ' + request.Status__c);
}

// Check if Provider__c is required
Schema.DescribeFieldResult providerField = CareBenefitVerifyRequest__c.Provider__c.getDescribe();
System.debug('Provider__c field:');
System.debug('  Required: ' + !providerField.isNillable());
System.debug('  References: ' + providerField.getReferenceTo());
System.debug('  Default Value: ' + providerField.getDefaultValue());
System.debug('  Createable: ' + providerField.isCreateable());
System.debug('  Updateable: ' + providerField.isUpdateable()); 