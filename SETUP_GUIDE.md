# Benefit Verification App - Setup Guide

## Prerequisites

1. **Salesforce Developer Account**
   - Go to [Salesforce Developer Edition Signup](https://developer.salesforce.com/signup)
   - Create a free Developer Edition org
   - Save your credentials

2. **Install Salesforce CLI**
   ```bash
   # For Mac (using Homebrew)
   brew install salesforce-cli

   # For Windows
   # Download installer from: https://developer.salesforce.com/tools/salesforcecli
   ```

3. **Install Visual Studio Code**
   - Download from [VS Code](https://code.visualstudio.com/)
   - Install Salesforce Extension Pack in VS Code

## Step-by-Step Deployment

1. **Authenticate to Your Org**
   ```bash
   # Open terminal and run
   sf org login web
   # Follow the browser prompts to log in
   ```

2. **Deploy the Application**
   ```bash
   # Navigate to the project directory
   cd benefit-verification-app

   # Deploy the application
   sf project deploy start
   ```

3. **Assign Permission Set**
   ```bash
   # Get your username
   sf org display user

   # Assign permission set
   sf org assign permset --name Benefit_Verification_User
   ```

4. **Configure Named Credential**
   - Log into your Salesforce org
   - Go to Setup → Named Credentials
   - Click "Benefit_Verification_API"
   - Update the endpoint URL if needed
   - Set the username to "test_user"
   - Set the password to "test_password"

## Testing the Application

### 1. Create Test Data

Run this in Developer Console (Setup → Developer Console → Debug → Open Execute Anonymous):

```apex
// Create test Patient Account
Account patient = new Account(
    FirstName = 'Test',
    LastName = 'Patient',
    Gender__c = 'Female',
    RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
);
insert patient;

// Create Provider Account
Account provider = new Account(
    Name = 'Dr. Test Provider',
    NPI = '1234567890',
    RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business').getRecordTypeId()
);
insert provider;

// Create Member Plan
MemberPlan plan = new MemberPlan(
    Name = 'Test Plan',
    PolicyNumber = 'POL123',
    GroupNumber = 'GRP456',
    SubscriberId = 'SUB789'
);
insert plan;

System.debug('Patient ID: ' + patient.Id);
System.debug('Provider ID: ' + provider.Id);
System.debug('Plan ID: ' + plan.Id);
```

### 2. Test UI Flow
1. Open App Launcher (nine dots in top left)
2. Find and click "Benefit Verification"
3. Click "Benefit Verification Creator" tab
4. Fill in the form:
   - Use the IDs from step 1
   - Select any Service Type
   - Pick today's date
   - Add any test codes (e.g., "A01.1" for diagnosis)
5. Click "Submit for Verification"

### 3. Test API Response
Run this in Developer Console:

```apex
// Get the latest request
CareBenefitVerifyRequest request = [
    SELECT Id FROM CareBenefitVerifyRequest 
    ORDER BY CreatedDate DESC LIMIT 1
];

// Test API response
String requestBody = JSON.serialize(new Map<String, Object>{
    'careBenefitVerifyRequestId' => request.Id,
    'benefitStatus' => 'Active Coverage',
    'copay' => 25.50,
    'deductible' => 550.00,
    'isCovered' => true
});

RestRequest req = new RestRequest();
RestResponse res = new RestResponse();
req.requestURI = '/services/apexrest/care-benefit-verification-results/';
req.httpMethod = 'POST';
req.requestBody = Blob.valueOf(requestBody);
RestContext.request = req;
RestContext.response = res;

CoverageBenefitResultController.createCoverageBenefit();

System.debug('Response: ' + res.responseBody.toString());
```

### 4. Verify Results
1. Check CareBenefitVerifyRequest status:
   ```apex
   SELECT Id, Status, External_API_Status__c 
   FROM CareBenefitVerifyRequest 
   ORDER BY CreatedDate DESC LIMIT 1
   ```

2. Check CoverageBenefit creation:
   ```apex
   SELECT Id, BenefitStatus, CopayAmount, DeductibleAmount 
   FROM CoverageBenefit 
   ORDER BY CreatedDate DESC LIMIT 1
   ```

## Common Issues & Solutions

1. **"Invalid Type" Error**
   - Ensure you've deployed all components
   - Check if Person Accounts are enabled in your org

2. **"Missing Permission" Error**
   - Verify permission set assignment
   - Check if user has API enabled

3. **"Invalid Session ID" Error**
   - Re-authenticate using `sf org login web`

4. **Named Credential Error**
   - Double-check credential settings in Setup
   - Verify endpoint URL is accessible

## Need Help?

1. Check Debug Logs:
   - Setup → Debug Logs
   - Set trace flags for your user
   - Perform the operation
   - Review the generated log

2. View Apex Jobs:
   - Setup → Apex Jobs
   - Check for any failed jobs

3. Common Salesforce Resources:
   - [Salesforce Developer Documentation](https://developer.salesforce.com/docs)
   - [Salesforce Trailhead](https://trailhead.salesforce.com/)
   - [Salesforce Stack Exchange](https://salesforce.stackexchange.com/) 