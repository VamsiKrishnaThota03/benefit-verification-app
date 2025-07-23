# Benefit Verification Salesforce Application

A native Salesforce app for electronic benefit verification, queue management, and API integration.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Staged Setup & Deployment](#staged-setup--deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Creating Test Data](#creating-test-data)
- [Using the App (UI Walkthrough)](#using-the-app-ui-walkthrough)
- [Testing the API Endpoint](#testing-the-api-endpoint)
- [Error Handling](#error-handling)
- [Security Notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

---

## Project Structure

- `force-app/` — Salesforce metadata (objects, fields, classes, LWC, etc.)
- `scripts/` — Apex scripts for test data and API testing
- `README.md` — This file
- `SETUP_GUIDE.md` — Additional setup and troubleshooting instructions
- `sfdx-project.json` — Salesforce project configuration

---

## Prerequisites

- Salesforce Developer Edition org (or sandbox)
- Salesforce CLI (`sf` or `sfdx`) installed
- Permission to deploy metadata and assign permission sets

---

## Staged Setup & Deployment

**Important:**
For a smooth deployment, deploy metadata in the following order to avoid dependency errors.

### 1. **Clone or Download the Project**

```bash
git clone <your-repo-url>
cd benefit-verification-app
```

### 2. **Authenticate to Your Salesforce Org**

```bash
sf org login web
```
- Log in to your Salesforce org in the browser window that opens.

### 3. **Staged Deployment Steps**

#### **A. Deploy Custom Objects and Fields First**

```bash
sf project deploy start --manifest manifest/package-objects.xml
```
- This deploys all custom objects and their fields.

#### **B. Deploy Permission Sets and Queues**

```bash
sf project deploy start --manifest manifest/package-permset.xml
sf project deploy start --manifest manifest/package-queues.xml
```

#### **C. Deploy Apex Classes and Triggers**

```bash
sf project deploy start --manifest manifest/package-apex.xml
```

#### **D. Deploy Lightning Web Components (LWC)**

```bash
sf project deploy start --source-dir force-app/main/default/lwc
```

#### **E. Deploy Tabs, Flexipages, and Application**

```bash
sf project deploy start --manifest manifest/package.xml
```

**Note:**
If you encounter deployment errors, deploy the metadata in even smaller chunks (e.g., deploy each object or permission set individually), then proceed to the next step.

> **Special Note: Permission Sets and Required Fields**
>
> If you get a deployment error like:
> 
> `You cannot deploy to a required field: CareBenefitVerifyRequest__c.ServiceType__c`
>
> **Do the following:**
> 1. Open the field’s metadata file (e.g., `force-app/main/default/objects/CareBenefitVerifyRequest__c/fields/ServiceType__c.field-meta.xml`).
> 2. Change `<required>true</required>` to `<required>false</required>`.
> 3. Deploy the permission sets and related metadata.
> 4. Change the field’s metadata back to `<required>true</required>`.
> 5. Redeploy the field metadata (and object, if needed).
>
> This ensures your deployment succeeds and your field remains required in the org.

### 4. **Assign the Permission Set**

```bash
sf org assign permset --name Benefit_Verification_User
```

---

## Post-Deployment Configuration

### 1. **Configure Named Credential**

- Go to **Setup → Named Credentials**.
- Edit `Benefit_Verification_API`:
  - **Endpoint:** `https://infinitusmockbvendpoint-rji9z4.5sc6y6-2.usa-e2.cloudhub.io/benefit-verification-request`
  - **Username:** `test_user`
  - **Password:** `test_password`
- Save.

### 2. **Add Tabs to App Navigation**

- Go to **Setup → App Manager**.
- Edit the **Benefit Verification** app.
- Add **Member Plans** and **Care Benefit Verify Requests** to the navigation bar.
- Save.

### 3. **(If Needed) Create Tabs for Custom Objects**

- Go to **Setup → Tabs**.
- Create new tabs for `MemberPlan__c` and `CareBenefitVerifyRequest__c` if not already present.

---

## Creating Test Data

### **A. Using the UI**

1. Go to the **Accounts** tab and create:
   - A Patient (e.g., "Demo Patient 001")
   - A Provider (e.g., "Demo Provider 001")
   - A Payer (e.g., "Demo Insurance Co 001")
2. Go to the **Member Plans** tab and create a new plan, linking to the above accounts.

### **B. Using Apex Script**

- Open **Developer Console → Execute Anonymous** and run:
```apex
// Create Patient Account
Account patient = new Account(Name = 'Demo Patient 001', Gender__c = 'Female');
insert patient;

// Create Provider Account
Account provider = new Account(Name = 'Demo Provider 001', NPI__c = '9876543210');
insert provider;

// Create Payer Account
Account payer = new Account(Name = 'Demo Insurance Co 001');
insert payer;

// Create Member Plan
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

---

## Using the App (UI Walkthrough)

### 1. **Create a Benefit Verification Request**

- Go to the **Benefit Verification Creator** tab.
- Use the lookup fields to select Patient, Member Plan, and Provider.
- Fill in Service Type, Service Date, Diagnosis Code, and Procedure Code.
- Click **Submit for Verification**.
- You should see a success message and the request should appear in the **Care Benefit Verify Requests** tab.

### 2. **Check Queue Assignment**

- In the **Care Benefit Verify Requests** tab, add the **Owner** column to the list view.
- Requests with Service Type "Consultation", "Infusion", or "Surgery" should be owned by the corresponding queue.

### 3. **View and Manage Records**

- Use the **Member Plans** and **Care Benefit Verify Requests** tabs to view, edit, and manage records.
- Use list view filters and search as needed.

---

## Testing the API Endpoint

### **Endpoint**
```
POST /services/apexrest/care-benefit-verification-results/v1/
```

### **Sample Request Payload**
```json
{
  "careBenefitVerifyRequestId": "a2Uxx00000043YnEAI",
  "benefitStatus": "Active Coverage",
  "copay": 25.50,
  "deductible": 550.00,
  "isCovered": true
}
```

### **How to Test**

- Use Postman or an Apex script (see `scripts/apex/test.apex`) to POST to the endpoint.
- The API will create a `CoverageBenefit__c` record and update the request status.

---

## Error Handling

- The app will show clear error messages for:
  - Missing required fields
  - Invalid data formats
  - API authentication or callout errors
  - Validation rule failures (e.g., mismatched Patient/Member Plan)
- API endpoint returns appropriate HTTP status codes and error messages.

---

## Security Notes

- All external API credentials are managed via **Named Credentials** (never hardcoded).
- Permission sets control access to objects and fields.
- Field-level security is enforced.
- For production, consider adding IP restrictions or OAuth/JWT authentication to the REST endpoint.

---

## Troubleshooting

- **Records not visible in UI:**  
  - Ensure tabs are added to the app navigation.
  - Check permission set assignment.
  - Refresh browser or log out/in.

- **Lookups not working in LWC:**  
  - Confirm field type is Lookup in Object Manager.
  - Check field-level security and page layout.

- **API errors:**  
  - Check Named Credential configuration.
  - Review debug logs in Setup.

- **Validation errors:**  
  - Ensure all required fields are filled and relationships are correct.

---

## Support

- For setup or usage questions, check the `SETUP_GUIDE.md` for detailed instructions.
- For code or deployment issues, review the debug logs in Salesforce Setup.
- For further help, contact [Your Name/Email].

---

**Enjoy using your Benefit Verification Salesforce Application!** 