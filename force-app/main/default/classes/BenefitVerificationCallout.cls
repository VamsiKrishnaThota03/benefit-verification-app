/**
 * Sends Care Benefit Verification Requests to the external verification API
 * (Named Credential Benefit_Verification_API) and records the outcome.
 *
 * This is the single submit path: CareBenefitVerifyRequestTrigger enqueues a
 * BenefitVerificationCallout.Job for every request inserted with status
 * Submitted, whether it came from the LWC form, BenefitVerificationController,
 * the API or a data load.
 *
 * Outcome handling:
 *   - 2xx response: External API status/reason are stored and the request moves
 *     to In Progress. If the response already contains benefit details
 *     (benefitStatus plus copay/deductible/isCovered), a CoverageBenefit__c is
 *     created from them and the request is Completed. Otherwise the request waits
 *     for the result to be posted to CoverageBenefitResultController.
 *   - Non-2xx response or exception: status Error with the reason recorded.
 *
 * Runs without sharing on purpose: it executes asynchronously after the
 * request has been routed to a queue, so the submitting user may no longer
 * own (or see) the record.
 */
public without sharing class BenefitVerificationCallout {

    public static final String NAMED_CREDENTIAL = 'callout:Benefit_Verification_API';
    /** Callouts per queueable execution; the platform limit is 100. */
    public static final Integer MAX_CALLOUTS_PER_JOB = 50;

    @TestVisible
    private static final Integer STATUS_MAX_LENGTH =
        CareBenefitVerifyRequest__c.External_API_Status__c.getDescribe().getLength();
    @TestVisible
    private static final Integer REASON_MAX_LENGTH =
        CareBenefitVerifyRequest__c.External_API_Status_Reason__c.getDescribe().getLength();

    /** Queues verification callouts for the given request Ids. */
    public static void enqueue(List<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new Job(requestIds));
    }

    /** Queueable worker; processes up to MAX_CALLOUTS_PER_JOB requests and chains the rest. */
    public class Job implements Queueable, Database.AllowsCallouts {
        private final List<Id> requestIds;

        public Job(List<Id> requestIds) {
            this.requestIds = new List<Id>(requestIds);
        }

        public void execute(QueueableContext context) {
            List<Id> batch = new List<Id>();
            List<Id> remaining = new List<Id>();
            for (Id requestId : requestIds) {
                if (batch.size() < MAX_CALLOUTS_PER_JOB) {
                    batch.add(requestId);
                } else {
                    remaining.add(requestId);
                }
            }

            verify(batch);

            // Chained jobs are not allowed inside Apex tests.
            if (!remaining.isEmpty() && !Test.isRunningTest()) {
                System.enqueueJob(new Job(remaining));
            }
        }
    }

    /**
     * Performs the callouts synchronously and saves the results.
     * Must run in a context that allows callouts (the Job above, or a test with a mock).
     */
    public static void verify(List<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) {
            return;
        }

        List<CareBenefitVerifyRequest__c> requests = [
            SELECT Id, Status__c, Patient__c, MemberPlan__c,
                   Patient__r.FirstName, Patient__r.LastName, Patient__r.PersonBirthdate, Patient__r.Gender__c,
                   MemberPlan__r.Name, MemberPlan__r.PolicyNumber__c, MemberPlan__r.GroupNumber__c,
                   MemberPlan__r.SubscriberId__c,
                   ProviderAccount__r.Name, ProviderAccount__r.NPI__c,
                   ServiceType__c, ServiceDate__c, DiagnosisCode__c, ProcedureCode__c,
                   External_API_Status__c, External_API_Status_Reason__c
            FROM CareBenefitVerifyRequest__c
            WHERE Id IN :requestIds
        ];

        List<CoverageBenefit__c> benefits = new List<CoverageBenefit__c>();
        for (CareBenefitVerifyRequest__c request : requests) {
            CoverageBenefit__c benefit = callOut(request);
            if (benefit != null) {
                benefits.add(benefit);
            }
        }

        // Partial success: one bad record must not roll back the others.
        logFailures(Database.update(requests, false), 'update CareBenefitVerifyRequest__c');
        if (!benefits.isEmpty()) {
            logFailures(Database.insert(benefits, false), 'insert CoverageBenefit__c');
        }
    }

    /** Sends one request and applies the outcome to the record; returns a benefit to insert, if any. */
    @TestVisible
    private static CoverageBenefit__c callOut(CareBenefitVerifyRequest__c request) {
        try {
            HttpRequest httpRequest = new HttpRequest();
            httpRequest.setEndpoint(NAMED_CREDENTIAL);
            httpRequest.setMethod('POST');
            httpRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
            httpRequest.setTimeout(30000);
            httpRequest.setBody(JSON.serialize(buildPayload(request)));

            HttpResponse response = new Http().send(httpRequest);
            Integer code = response.getStatusCode();
            if (code < 200 || code >= 300) {
                markError(request, 'API Error',
                    'HTTP ' + code + ' ' + response.getStatus() + ': ' + response.getBody());
                return null;
            }
            return applySuccess(request, response.getBody());
        } catch (Exception e) {
            markError(request, 'System Error', e.getTypeName() + ': ' + e.getMessage());
            return null;
        }
    }

    @TestVisible
    private static CoverageBenefit__c applySuccess(CareBenefitVerifyRequest__c request, String body) {
        BenefitVerificationResponse parsed;
        try {
            parsed = String.isBlank(body)
                ? new BenefitVerificationResponse()
                : (BenefitVerificationResponse) JSON.deserialize(body, BenefitVerificationResponse.class);
        } catch (JSONException e) {
            markError(request, 'Invalid Response', 'Could not parse API response: ' + e.getMessage());
            return null;
        }

        request.External_API_Status__c = truncate(
            String.isBlank(parsed.status) ? 'Acknowledged' : parsed.status, STATUS_MAX_LENGTH);
        request.External_API_Status_Reason__c = truncate(parsed.statusReason, REASON_MAX_LENGTH);

        if (!parsed.hasBenefitDetails()) {
            request.Status__c = 'In Progress';
            return null;
        }

        request.Status__c = 'Completed';
        return new CoverageBenefit__c(
            CareBenefitVerifyRequest__c = request.Id,
            Patient__c = request.Patient__c,
            MemberPlan__c = request.MemberPlan__c,
            BenefitStatus__c = truncate(parsed.benefitStatus, 50),
            CopayAmount__c = parsed.copay,
            DeductibleAmount__c = parsed.deductible,
            IsCovered__c = parsed.isCovered == true,
            VerificationDate__c = System.now()
        );
    }

    /** Builds the JSON payload expected by the verification API. */
    @TestVisible
    private static Map<String, Object> buildPayload(CareBenefitVerifyRequest__c request) {
        String providerFirstName = '';
        String providerLastName = '';
        if (request.ProviderAccount__r != null && String.isNotBlank(request.ProviderAccount__r.Name)) {
            List<String> parts = request.ProviderAccount__r.Name.trim().split(' ', 2);
            providerFirstName = parts[0];
            providerLastName = parts.size() > 1 ? parts[1].trim() : '';
        }

        return new Map<String, Object>{
            'patientDetails' => new Map<String, Object>{
                'firstName' => request.Patient__r?.FirstName,
                'lastName' => request.Patient__r?.LastName,
                'dateOfBirth' => request.Patient__r?.PersonBirthdate,
                'gender' => request.Patient__r?.Gender__c
            },
            'insuranceInformation' => new Map<String, Object>{
                'insuranceProviderName' => request.MemberPlan__r?.Name,
                'policyNumber' => request.MemberPlan__r?.PolicyNumber__c,
                'groupNumber' => request.MemberPlan__r?.GroupNumber__c,
                'subscriberId' => request.MemberPlan__r?.SubscriberId__c
            },
            'providerInformation' => new Map<String, Object>{
                'nationalProviderIdentifier' => request.ProviderAccount__r?.NPI__c,
                'firstName' => providerFirstName,
                'lastName' => providerLastName
            },
            'serviceDetails' => new Map<String, Object>{
                'serviceType' => request.ServiceType__c,
                'serviceDate' => request.ServiceDate__c,
                'diagnosisCode' => request.DiagnosisCode__c,
                'procedureCode' => request.ProcedureCode__c
            }
        };
    }

    private static void markError(CareBenefitVerifyRequest__c request, String status, String reason) {
        request.Status__c = 'Error';
        request.External_API_Status__c = truncate(status, STATUS_MAX_LENGTH);
        request.External_API_Status_Reason__c = truncate(reason, REASON_MAX_LENGTH);
    }

    @TestVisible
    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private static void logFailures(List<Database.SaveResult> results, String operation) {
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'BenefitVerificationCallout: failed to ' + operation
                        + ' ' + result.getId() + ': ' + error.getStatusCode() + ' ' + error.getMessage());
                }
            }
        }
    }
}
