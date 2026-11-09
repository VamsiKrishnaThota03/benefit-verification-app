/**
 * Test data factory shared by the benefit verification tests.
 * Requires Person Accounts (the callout reads Patient__r.FirstName / PersonBirthdate).
 */
@isTest
public class BenefitVerificationTestData {

    public static Id personAccountRecordTypeId() {
        Schema.RecordTypeInfo info =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount');
        System.assertNotEquals(null, info, 'Person Accounts must be enabled to run these tests.');
        return info.getRecordTypeId();
    }

    /** Any active business (non-person) Account record type, or null to use the default. */
    public static Id businessAccountRecordTypeId() {
        List<SObject> rows = Database.query(
            'SELECT Id FROM RecordType WHERE SobjectType = \'Account\' AND IsPersonType = false AND IsActive = true LIMIT 1'
        );
        return rows.isEmpty() ? null : rows[0].Id;
    }

    public static Account createPatient(String firstName, String lastName) {
        Account patient = new Account(
            FirstName = firstName,
            LastName = lastName,
            Gender__c = 'Female',
            RecordTypeId = personAccountRecordTypeId()
        );
        insert patient;
        return patient;
    }

    public static Account createBusinessAccount(String name, String npi) {
        Account account = new Account(Name = name, NPI__c = npi);
        Id recordTypeId = businessAccountRecordTypeId();
        if (recordTypeId != null) {
            account.RecordTypeId = recordTypeId;
        }
        insert account;
        return account;
    }

    /** A member plan that satisfies all required fields and the ValidMemberPlan rule for the patient. */
    public static MemberPlan__c createPlan(Account patient, Account payer) {
        MemberPlan__c plan = new MemberPlan__c(
            Name = 'Gold Plan',
            PolicyNumber__c = 'POL123',
            GroupNumber__c = 'GRP456',
            SubscriberId__c = 'SUB789',
            MemberNumber__c = 'MEM001',
            Member__c = patient.Id,
            Subscriber__c = patient.Id,
            Payer__c = payer.Id,
            EffectiveFrom__c = Date.today(),
            EffectiveTo__c = Date.today().addYears(1)
        );
        insert plan;
        return plan;
    }

    public static CareBenefitVerifyRequest__c newRequest(Account patient, MemberPlan__c plan, Account provider,
                                                         String serviceType, String status) {
        return new CareBenefitVerifyRequest__c(
            Patient__c = patient.Id,
            MemberPlan__c = plan.Id,
            ProviderAccount__c = provider?.Id,
            ServiceType__c = serviceType,
            ServiceDate__c = Date.today(),
            DiagnosisCode__c = 'A01.1',
            ProcedureCode__c = '99213',
            Status__c = status
        );
    }

    /** Standard fixture: patient, provider, payer and plan. Returns them keyed by role. */
    public static Map<String, SObject> createFixture() {
        Account patient = createPatient('Jane', 'Doe');
        Account provider = createBusinessAccount('John Smith MD', '1234567890');
        Account payer = createBusinessAccount('Acme Insurance', null);
        MemberPlan__c plan = createPlan(patient, payer);
        return new Map<String, SObject>{
            'patient' => patient, 'provider' => provider, 'payer' => payer, 'plan' => plan
        };
    }

    /**
     * Returns the Care queues by developer name. They normally come from the
     * deployed queue metadata; any that are missing are created (in a runAs
     * block to avoid mixed DML with the test's data records).
     */
    public static Map<String, Id> careQueues() {
        Set<String> names = new Set<String>(CareBenefitVerifyRequestTriggerHandler.QUEUE_BY_SERVICE_TYPE.values());
        Map<String, Id> queues = new Map<String, Id>();
        for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :names]) {
            queues.put(g.DeveloperName, g.Id);
        }
        if (queues.size() < names.size()) {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                List<Group> missing = new List<Group>();
                for (String name : names) {
                    if (!queues.containsKey(name)) {
                        missing.add(new Group(Name = name.replace('_', ' '), DeveloperName = name, Type = 'Queue'));
                    }
                }
                insert missing;
                List<QueueSobject> links = new List<QueueSobject>();
                for (Group g : missing) {
                    links.add(new QueueSobject(QueueId = g.Id, SobjectType = 'CareBenefitVerifyRequest__c'));
                    queues.put(g.DeveloperName, g.Id);
                }
                insert links;
            }
        }
        return queues;
    }

    /** HttpCalloutMock returning a fixed status code and JSON body. */
    public class MockResponse implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        public HttpRequest lastRequest;

        public MockResponse(Integer statusCode, Map<String, Object> body) {
            this(statusCode, JSON.serialize(body));
        }

        public MockResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            lastRequest = req;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /** HttpCalloutMock that simulates a network failure. */
    public class FailingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Read timed out');
        }
    }
}
