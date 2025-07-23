// Check fields on HealthCloudGA__Provider__c
System.debug('=== Checking HealthCloudGA__Provider__c Fields ===');

// Get the describe result for HealthCloudGA__Provider__c
Schema.DescribeSObjectResult describeResult = HealthCloudGA__Provider__c.SObjectType.getDescribe();

// Check fields
Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
for(String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    System.debug(fieldName + ':');
    System.debug('  Label: ' + field.getLabel());
    System.debug('  Type: ' + field.getType());
    System.debug('  Required: ' + !field.isNillable());
    if(field.getReferenceTo().size() > 0) {
        System.debug('  References: ' + field.getReferenceTo());
    }
    System.debug('---');
} 