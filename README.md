# Benefit Verification App

A native Salesforce app that creates care benefit verification requests, routes them to queues by service type, and sends them to an external verification API.

![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?logo=salesforce&logoColor=white)
![Apex](https://img.shields.io/badge/Apex-1798C1?logo=salesforce&logoColor=white)
![LWC](https://img.shields.io/badge/Lightning%20Web%20Components-032D60?logo=salesforce&logoColor=white)
![API 58.0](https://img.shields.io/badge/Salesforce%20API-58.0-blue)

## Overview

The app is a Salesforce DX project (`force-app/`). It adds custom objects for member plans, verification requests and coverage benefits. It also includes a Lightning Web Component for entering requests, an Apex trigger that routes and submits each new request, and an Apex REST endpoint that receives verification results.

The basic flow:

1. A user fills in the **Benefit Verification Creator** form: patient, member plan, provider, service type, service date, diagnosis code and procedure code.
2. On insert, `CareBenefitVerifyRequestTrigger` assigns the request to a queue based on its service type.
3. For requests with status `Submitted`, the trigger calls a `@future` Apex callout. The callout POSTs patient, insurance, provider and service details as JSON to the `Benefit_Verification_API` Named Credential.
4. The external status and reason are saved on the request. On a successful response, a `CoverageBenefit__c` record is created and the request is marked `Completed`. Failures set the status to `Error`.
5. An external system can also post results back to the Apex REST endpoint, which creates a `CoverageBenefit__c` record.

## Features

- **Custom data model**
  - `MemberPlan__c`: member, payer, subscriber, policy, group and member numbers, effective dates
  - `CareBenefitVerifyRequest__c`: patient, member plan, provider, service details, status, external API status and reason
  - `CoverageBenefit__c`: benefit status, copay, deductible, covered flag, verification date
  - `Provider__c`, plus `NPI__c` and `Gender__c` fields on `Account`
- **LWC request form** (`benefitVerificationCreator`) built on `lightning-record-edit-form`, with toast feedback, exposed as the *Benefit Verification Creator* tab
- **Queue routing by service type**: Consultation, Infusion or Surgery go to the matching `*_Care_Queue`. `*_Verification_Queue` queues are also included and used by `BenefitVerificationController`.
- **Outbound callout** to an external benefit verification API through a Named Credential (`@future(callout=true)`)
- **Inbound Apex REST endpoint** that records coverage benefit results
- **Validation rule** `ValidMemberPlan`, which requires the selected member plan to belong to the selected patient
- **Lightning app** *Benefit Verification* with request, creator and coverage benefit tabs
- **Permission sets**: `Benefit_Verification_User`, `Benefit_Verification_Basic`, `Benefit_Verification_Fields`, `Benefit_Verification_ServiceType`
- **Apex test classes** for the callout, controller, REST endpoint and trigger, using HTTP callout mocks
- **Staged deployment manifests** in `manifest/` and helper anonymous Apex scripts in `scripts/apex/`

## Tech stack

- Salesforce Platform (Health Cloud org, source API version 58.0)
- Apex (classes, trigger, REST resource, `@future` callouts)
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
│   ├── queues/              # Care and Verification queues per service type
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

Go to **Setup → Named Credentials** and edit `Benefit_Verification_API`:

| Setting  | Value                                         |
|----------|-----------------------------------------------|
| Endpoint | `<your-benefit-verification-api-url>`         |
| Username | `<api-username>`                              |
| Password | `<api-password>`                              |

The repo's metadata points to a mock endpoint. Replace it with your own endpoint and credentials.

### 5. Create test data

From **Developer Console → Execute Anonymous**:

```apex
Account patient = new Account(Name = 'Demo Patient 001', Gender__c = 'Female');
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
sf apex run test --test-level RunLocalTests --result-format human --wait 10
```

## Using the app

1. Open the **Benefit Verification** app and go to the **Benefit Verification Creator** tab.
2. Select a Patient, Member Plan and Provider. Fill in Service Type, Service Date, Diagnosis Code and Procedure Code, then submit.
3. In **Care Benefit Verify Requests**, add the **Owner** column to the list view. Consultation, Infusion and Surgery requests should be owned by the matching queue.
4. After the callout runs, check **External API Status** and **External API Status Reason** on the request, and the related **Coverage Benefit** record.

See [TESTING_INSTRUCTIONS.md](TESTING_INSTRUCTIONS.md) and [SETUP_GUIDE.md](SETUP_GUIDE.md) for more detail.

## API

### Outbound: benefit verification callout

`POST callout:Benefit_Verification_API`. The body contains `patientDetails`, `insuranceInformation`, `providerInformation` and `serviceDetails`. The response must include `status` and `statusReason`.

### Inbound: Apex REST endpoint

| Method | Path                                                         | Purpose                                                                 |
|--------|--------------------------------------------------------------|-------------------------------------------------------------------------|
| POST   | `/services/apexrest/care-benefit-verification-results/v1/`   | Create a `CoverageBenefit__c` for a request and mark the request `Completed`. Returns `201` with `coverageBenefitId`, `400` if the request ID is missing, `500` on error |

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
