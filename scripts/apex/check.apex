// Check if MemberPlan__c exists and its fields
System.debug('Checking MemberPlan__c object and fields...');

// Get the describe result for MemberPlan__c
Schema.DescribeSObjectResult describeResult = MemberPlan__c.SObjectType.getDescribe();
System.debug('Object exists: ' + describeResult.getName());

// Get all fields
Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
System.debug('Fields available:');
for(String fieldName : fieldMap.keySet()) {
    System.debug(fieldName);
} 