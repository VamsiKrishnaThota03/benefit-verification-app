/**
 * Inbound REST endpoint for verification results:
 *   POST /services/apexrest/care-benefit-verification-results/v1/
 *
 * Body: { "careBenefitVerifyRequestId": "...", "benefitStatus": "Active",
 *         "copay": 25.50, "deductible": 550.00, "isCovered": true }
 *
 * Responses: 201 {coverageBenefitId}, 400 invalid input, 404 unknown request,
 * 500 unexpected error (details are logged, not returned).
 */
@RestResource(urlMapping='/care-benefit-verification-results/v1/*')
global with sharing class CoverageBenefitResultController {

    @HttpPost
    global static void createCoverageBenefit() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        Map<String, Object> body;
        try {
            Blob raw = RestContext.request.requestBody;
            Object parsed = raw == null ? null : JSON.deserializeUntyped(raw.toString());
            if (!(parsed instanceof Map<String, Object>)) {
                respond(res, 400, 'error', 'Request body must be a JSON object.');
                return;
            }
            body = (Map<String, Object>) parsed;
        } catch (JSONException e) {
            respond(res, 400, 'error', 'Request body is not valid JSON.');
            return;
        }

        Id requestId;
        String benefitStatus;
        Decimal copay;
        Decimal deductible;
        Boolean isCovered;
        try {
            requestId = toId(body.get('careBenefitVerifyRequestId'));
            benefitStatus = (String) body.get('benefitStatus');
            copay = toDecimal(body.get('copay'), 'copay');
            deductible = toDecimal(body.get('deductible'), 'deductible');
            isCovered = toBoolean(body.get('isCovered'));
        } catch (IllegalArgumentException e) {
            respond(res, 400, 'error', e.getMessage());
            return;
        } catch (TypeException e) {
            respond(res, 400, 'error', 'Invalid field type: ' + e.getMessage());
            return;
        }
        if (String.isBlank(benefitStatus)) {
            respond(res, 400, 'error', 'benefitStatus is required.');
            return;
        }

        List<CareBenefitVerifyRequest__c> matches = [
            SELECT Id, Patient__c, MemberPlan__c
            FROM CareBenefitVerifyRequest__c
            WHERE Id = :requestId
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            respond(res, 404, 'error', 'No CareBenefitVerifyRequest__c found for that Id.');
            return;
        }
        CareBenefitVerifyRequest__c request = matches[0];

        Savepoint sp = Database.setSavepoint();
        try {
            CoverageBenefit__c benefit = new CoverageBenefit__c(
                CareBenefitVerifyRequest__c = request.Id,
                Patient__c = request.Patient__c,
                MemberPlan__c = request.MemberPlan__c,
                BenefitStatus__c = benefitStatus.left(50),
                CopayAmount__c = copay,
                DeductibleAmount__c = deductible,
                IsCovered__c = isCovered == true,
                VerificationDate__c = System.now()
            );
            insert benefit;

            request.Status__c = 'Completed';
            update request;

            respond(res, 201, 'coverageBenefitId', benefit.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'CoverageBenefitResultController: ' + e.getMessage());
            respond(res, 400, 'error', 'Could not save the coverage benefit: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'CoverageBenefitResultController: '
                + e.getMessage() + '\n' + e.getStackTraceString());
            respond(res, 500, 'error', 'Unexpected error while saving the coverage benefit.');
        }
    }

    private static Id toId(Object value) {
        String text = value == null ? null : String.valueOf(value);
        if (String.isBlank(text)) {
            throw new IllegalArgumentException('careBenefitVerifyRequestId is required.');
        }
        Id parsed;
        try {
            parsed = Id.valueOf(text);
        } catch (StringException e) {
            throw new IllegalArgumentException('careBenefitVerifyRequestId is not a valid Salesforce Id.');
        }
        if (parsed.getSobjectType() != CareBenefitVerifyRequest__c.SObjectType) {
            throw new IllegalArgumentException('careBenefitVerifyRequestId must reference a CareBenefitVerifyRequest__c.');
        }
        return parsed;
    }

    private static Decimal toDecimal(Object value, String field) {
        if (value == null) {
            return null;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        if (value instanceof Integer) {
            return Decimal.valueOf((Integer) value);
        }
        if (value instanceof Long) {
            return Decimal.valueOf((Long) value);
        }
        throw new IllegalArgumentException(field + ' must be a number.');
    }

    private static Boolean toBoolean(Object value) {
        if (value == null || value instanceof Boolean) {
            return (Boolean) value;
        }
        throw new IllegalArgumentException('isCovered must be true or false.');
    }

    private static void respond(RestResponse res, Integer statusCode, String key, String value) {
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ key => value }));
    }
}
