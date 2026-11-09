# Benefit Verification App

A native Salesforce app that creates care benefit verification requests, routes them to queues by service type, and sends them to an external verification API.

![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?logo=salesforce&logoColor=white)
![Apex](https://img.shields.io/badge/Apex-1798C1?logo=salesforce&logoColor=white)
![LWC](https://img.shields.io/badge/Lightning%20Web%20Components-032D60?logo=salesforce&logoColor=white)
![API 58.0](https://img.shields.io/badge/Salesforce%20API-58.0-blue)

## Overview

The app is a Salesforce DX project (`force-app/`). It adds custom objects for member plans, verification requests and coverage benefits. It also includes a Lightning Web Component for entering requests, an Apex trigger that routes and submits each new request, and an Apex REST endpoint that receives verification results.

The basic flow:

1. A user fills in the **Benefit Verification Creator** form: patient, member plan, provider, service type, service date, diagnosis code and procedure code. The form always saves the request with status `Submitted`.
2. On insert, `CareBenefitVerifyRequestTrigger` (logic in `CareBenefitVerifyRequestTriggerHandler`) assigns the request to the care queue for its service type.
3. For every request inserted with status `Submitted`, the trigger enqueues a `BenefitVerificationCallout.Job` (Queueable with callouts, up to 50 requests per job, chained for larger loads). The job POSTs patient, insurance, provider and service details as JSON to the `Benefit_Verification_API` Named Credential.
4. The external status and reason are saved on the request:
   - `2xx` acknowledgement: status `In Progress`, waiting for results.
   - `2xx` with benefit details (`benefitStatus` plus `copay`, `deductible` or `isCovered`): a `CoverageBenefit__c` is created from those values and the request becomes `Completed`.
   - Non-`2xx`, unparseable response or callout exception: status `Error`, with the reason recorded.
5. The external system posts results to the Apex REST endpoint, which creates a `CoverageBenefit__c` and marks the request `Completed`.

There is a single submit path. `BenefitVerificationController.createBenefitVerificationRequest` (for Aura/LWC or Apex callers) only inserts the request, so routing and the callout come from the trigger exactly as they do for the form, the API or data loads.

## Features

- **Custom data model**
  - `MemberPlan__c`: member, payer, subscriber, policy, group and member numbers, effective dates
  - `CareBenefitVerifyRequest__c`: patient, member plan, provider, service details, status, external API status and reason
  - `CoverageBenefit__c`: benefit status, copay, deductible, covered flag, verification date
  - `Provider__c`, plus `NPI__c` and `Gender__c` fields on `Account`
- **LWC request form** (`benefitVerificationCreator`) built on `lightning-record-edit-form`, with a loading spinner, inline error banner, success banner with a link to the new request, a Clear button and toasts, exposed as the *Benefit Verification Creator* tab
- **Queue routing by service type**: Consultation, Infusion or Surgery go to the matching `*_Care_Queue`. `Other` stays with the creator.
- **Outbound callout** to an external benefit verification API through a Named Credential (Queueable with `Database.AllowsCallouts`, bulk-safe, partial-success DML)
- **Inbound Apex REST endpoint** that validates input and records coverage benefit results (`201`/`400`/`404`/`500`, no stack traces returned)
- **Validation rule** `ValidMemberPlan`, which requires the selected member plan to belong to the selected patient
- **Lightning app** *Benefit Verification* with request, creator and coverage benefit tabs
- **Permission sets**: `Benefit_Verification_User`, `Benefit_Verification_Basic`, `Benefit_Verification_Fields`, `Benefit_Verification_ServiceType`
- **Apex test classes** for the callout, controller, REST endpoint and trigger, with a shared `BenefitVerificationTestData` factory and HTTP callout mocks
- **Staged deployment manifests** in `manifest/` and helper anonymous Apex scripts in `scripts/apex/`

## Tech stack

- Salesforce Platform (Health Cloud org, source API version 58.0)
- Apex (classes, trigger, REST resource, Queueable callouts)
- Lightning Web Components
- Salesforce CLI (`sf`)

## Project structure

```
.
├── force-app/main/default/
│   ├── applications/        # Benefit Verification Lightning app
│   ├── classes/             # Apex controllers, callouts, REST resource, tests
│   ├── triggers/            # CareBenefitVerifyRequestTrigger
│   ├── lwc/                 # benefitVerificationCreator component
│   ├── objects/             # Custom objects, fields, list views, validation rules
│   ├── namedCredentials/    # Benefit_Verification_API
│   ├── permissionsets/
│   ├── queues/              # Care queue per service type
│   ├── tabs/ flexipages/
├── manifest/                # package*.xml manifests for staged deploys
├── scripts/apex/            # Anonymous Apex for test data and checks
├── SETUP_GUIDE.md           # Extra setup and troubleshooting notes
├── TESTING_INSTRUCTIONS.md  # Manual test steps
└── sfdx-project.json
```

## Getting started

### Prerequisites

- A Salesforce org (Developer Edition, sandbox, or Health Cloud org). The callout reads `Patient__r.FirstName` and `PersonBirthdate`, so Person Accounts must be enabled.
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- Permission to deploy metadata and assign permission sets

### 1. Clone and authenticate

```bash
git clone https://github.com/VamsiKrishnaThota03/benefit-verification-app.git
cd benefit-verification-app
sf org login web
```

### 2. Deploy in stages

Deploy in this order to avoid dependency errors:

```bash
# A. Custom objects and fields
sf project deploy start --manifest manifest/package-objects.xml

# B. Permission sets and queues
sf project deploy start --manifest manifest/package-permset.xml
sf project deploy start --manifest manifest/package-queues.xml

# C. Apex classes and triggers
sf project deploy start --manifest manifest/package-apex.xml

# D. Lightning Web Components
sf project deploy start --source-dir force-app/main/default/lwc

# E. Tabs, flexipages and application
sf project deploy start --manifest manifest/package.xml
```

If a step fails, deploy smaller pieces (for example one object or permission set at a time), then continue.

> **Required fields and permission sets**
> If you see `You cannot deploy to a required field: CareBenefitVerifyRequest__c.ServiceType__c`:
> 1. In `force-app/main/default/objects/CareBenefitVerifyRequest__c/fields/ServiceType__c.field-meta.xml`, change `<required>true</required>` to `false`.
> 2. Deploy the permission sets.
> 3. Change the field back to `<required>true</required>` and redeploy it.

### 3. Assign the permission set

```bash
sf org assign permset --name Benefit_Verification_User
```

### 4. Configure the Named Credential

The Named Credential metadata contains the endpoint only. **No username or password is stored in the repository.** After deploying, go to **Setup → Named Credentials**, edit `Benefit_Verification_API`, and set:

| Setting  | Value                                         |
|----------|-----------------------------------------------|
| URL      | `<your-benefit-verification-api-url>`         |
| Username | `<api-username>`                              |
| Password | `<api-password>`                              |

The repo's metadata points to a mock CloudHub endpoint and a placeholder username. Replace both with your own. Redeploying the Named Credential resets the username to the placeholder and clears the password, so either re-enter them afterwards or leave `namedCredentials/` out of later deploys.

### 5. Create test data

From **Developer Console → Execute Anonymous**:

```apex
Account patient = new Account(
    FirstName = 'Demo', LastName = 'Patient 001', Gender__c = 'Female',
    RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
);
insert patient;
Account provider = new Account(Name = 'Demo Provider 001', NPI__c = '9876543210');
insert provider;
Account payer = new Account(Name = 'Demo Insurance Co 001');
insert payer;

MemberPlan__c plan = new MemberPlan__c(
    Name = 'Demo Plan 001',
    GroupNumber__c = 'GRP-001',
    PolicyNumber__c = 'POL-001',
    SubscriberId__c = 'SUB-001',
    MemberNumber__c = 'MEM-001',
    EffectiveFrom__c = Date.today(),
    EffectiveTo__c = Date.today().addYears(1),
    Member__c = patient.Id,
    Payer__c = payer.Id,
    Subscriber__c = patient.Id
);
insert plan;
```

`scripts/apex/setup-test-data.apex` has a similar script.

### 6. Run Apex tests

```bash
sf apex run test --test-level RunLocalTests --result-format human --code-coverage --wait 10
```

The tests need Person Accounts enabled. They use the deployed care queues, or create them if they are missing.

## Using the app

1. Open the **Benefit Verification** app and go to the **Benefit Verification Creator** tab.
2. Select a Patient, Member Plan and Provider. Fill in Service Type, Service Date, Diagnosis Code and Procedure Code, then submit.
3. In **Care Benefit Verify Requests**, add the **Owner** column to the list view. Consultation, Infusion and Surgery requests should be owned by the matching queue.
4. After the callout runs, check **External API Status** and **External API Status Reason** on the request, and the related **Coverage Benefit** record.

See [TESTING_INSTRUCTIONS.md](TESTING_INSTRUCTIONS.md) and [SETUP_GUIDE.md](SETUP_GUIDE.md) for more detail.

## API

### Outbound: benefit verification callout

`POST callout:Benefit_Verification_API`. The body contains `patientDetails`, `insuranceInformation`, `providerInformation` and `serviceDetails`. The response should include `status` and `statusReason`. It may also include `benefitStatus`, `copay`, `deductible` and `isCovered`, in which case the coverage benefit is recorded right away.

### Inbound: Apex REST endpoint

| Method | Path                                                         | Purpose                                                                 |
|--------|--------------------------------------------------------------|-------------------------------------------------------------------------|
| POST   | `/services/apexrest/care-benefit-verification-results/v1/`   | Create a `CoverageBenefit__c` for a request and mark the request `Completed`. Returns `201` with `coverageBenefitId`; `400` for invalid JSON, a missing or malformed request ID, a missing `benefitStatus` or wrong field types; `404` if the request does not exist or is not visible to the integration user; `500` on unexpected errors (details go to the debug log only) |

Sample payload:

```json
{
  "careBenefitVerifyRequestId": "a2Uxx00000043YnEAI",
  "benefitStatus": "Active Coverage",
  "copay": 25.50,
  "deductible": 550.00,
  "isCovered": true
}
```

You can test it with Postman, with an authenticated Salesforce session, or with `scripts/apex/test.apex`.

## Troubleshooting

- **Records not visible**: make sure the tabs are in the app navigation and the permission set is assigned. Then refresh.
- **Lookups not working in the form**: confirm the fields are Lookup type and check field-level security.
- **Callout errors**: check the Named Credential settings and the debug logs. The error details are written to `External_API_Status_Reason__c`.
- **Validation errors**: the Member Plan's member must be the selected Patient.

## Known limitations

- The changes in this version were reviewed statically only. They have **not** been deployed to an org and the Apex tests have **not** been run, because no Salesforce org or CLI was available. Deploy to a sandbox and run `RunLocalTests` before relying on them.
- Person Accounts are required (the callout reads `Patient__r.FirstName` and `PersonBirthdate`).
- Requests owned by a queue are processed by the verification job without sharing, but the REST endpoint runs with sharing, so the integration user needs access to the requests it updates.
- If an org has already used up its Queueable limit in a transaction (for example, inserts from inside a batch that already enqueued a job), new requests are saved but not sent. The trigger logs this. Resubmit them by inserting new requests or by running `BenefitVerificationCallout.enqueue(ids)` from anonymous Apex.
- `objects/CareBenefitVerifyRequest/` holds fields for the standard Health Cloud `CareBenefitVerifyRequest` object. The code does not use them, and they only deploy to orgs with Health Cloud.
