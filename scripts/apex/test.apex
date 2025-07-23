// Sample script for testing the CoverageBenefitResultController endpoint
// Before running, get a valid CareBenefitVerifyRequest ID from your org

String requestId = 'YOUR_RECORD_ID_HERE'; // <-- IMPORTANT: REPLACE THIS

RestRequest req = new RestRequest();
RestResponse res = new RestResponse();

req.requestURI = '/services/apexrest/care-benefit-verification-results/v1/';
req.httpMethod = 'POST';
req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
    'careBenefitVerifyRequestId' => requestId,
    'benefitStatus' => 'Active Coverage',
    'copay' => 25.50,
    'deductible' => 550.00,
    'isCovered' => true
}));

RestContext.request = req;
RestContext.response = res;

CoverageBenefitResultController.createCoverageBenefit();

System.debug('Status Code: ' + res.statusCode);
System.debug('Response Body: ' + res.responseBody.toString());
