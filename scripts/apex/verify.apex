// Verify MemberPlan__c fields
System.debug('=== Verifying MemberPlan__c fields ===');

// Get field describe results
Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.MemberPlan__c.fields.getMap();

// Check specific fields
Schema.DescribeFieldResult groupNumberField = fieldMap.get('GroupNumber__c').getDescribe();
Schema.DescribeFieldResult policyNumberField = fieldMap.get('PolicyNumber__c').getDescribe();
Schema.DescribeFieldResult subscriberIdField = fieldMap.get('SubscriberId__c').getDescribe();

System.debug('GroupNumber__c exists: ' + (groupNumberField != null));
System.debug('GroupNumber__c accessible: ' + groupNumberField.isAccessible());
System.debug('GroupNumber__c createable: ' + groupNumberField.isCreateable());

System.debug('PolicyNumber__c exists: ' + (policyNumberField != null));
System.debug('PolicyNumber__c accessible: ' + policyNumberField.isAccessible());
System.debug('PolicyNumber__c createable: ' + policyNumberField.isCreateable());

System.debug('SubscriberId__c exists: ' + (subscriberIdField != null));
System.debug('SubscriberId__c accessible: ' + subscriberIdField.isAccessible());
System.debug('SubscriberId__c createable: ' + subscriberIdField.isCreateable()); 