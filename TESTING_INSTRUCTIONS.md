# Benefit Verification App – UI Testing Instructions

This guide walks you through testing the full end-to-end flow of the Benefit Verification Salesforce Application using the Salesforce UI.

---

## 1. Log in to Salesforce
- Open your Salesforce org in your browser.

---

## 2. Create Test Data

### A. Create Patient Account
1. Go to the **Accounts** tab.
2. Click **New**.
3. Enter:
   - **Name:** Demo Patient 001
   - **Gender:** (select any value)
4. Click **Save**.

### B. Create Provider Account
1. Go to the **Accounts** tab.
2. Click **New**.
3. Enter:
   - **Name:** Demo Provider 001
   - **NPI:** 9876543210
4. Click **Save**.

### C. Create Payer Account
1. Go to the **Accounts** tab.
2. Click **New**.
3. Enter:
   - **Name:** Demo Insurance Co 001
4. Click **Save**.

### D. Create Member Plan
1. Go to the **Member Plans** tab.
2. Click **New**.
3. Enter:
   - **Name:** Demo Plan 001
   - **Group Number:** GRP-001
   - **Policy Number:** POL-001
   - **Subscriber ID:** SUB-001
   - **Member Number:** MEM-001
   - **Effective From:** Today’s date
   - **Effective To:** One year from today
   - **Member:** Lookup and select **Demo Patient 001**
   - **Payer:** Lookup and select **Demo Insurance Co 001**
   - **Subscriber:** Lookup and select **Demo Patient 001**
4. Click **Save**.

---

## 3. Create a Benefit Verification Request

1. Go to the **Benefit Verification Creator** tab.
2. Fill in the form:
   - **Patient:** Lookup and select **Demo Patient 001**
   - **Member Plan:** Lookup and select **Demo Plan 001**
   - **Provider:** Lookup and select **Demo Provider 001**
   - **Service Type:** Select any (e.g., Consultation)
   - **Service Date:** Today’s date
   - **Diagnosis Code:** (e.g., A01.1)
   - **Procedure Code:** (e.g., 99213)
3. Click **Submit for Verification**.
4. You should see a **success message**.

---

## 4. Verify the Request Record

1. Go to the **Care Benefit Verify Requests** tab.
2. Find the record you just created (sort by "Recently Viewed" if needed).
3. Click on the record to open it.
4. Check the following fields:
   - **Status:** Starts as "Submitted". After the verification job runs (usually a few seconds) it becomes:
     - "In Progress" when the API acknowledges the request,
     - "Completed" when the API response already includes benefit details (a Coverage Benefit is created), or
     - "Error" if the call failed. The reason is in **External API Status Reason**.
   - **External API Status:** The status returned by the API (for example "Acknowledged")
   - **External API Status Reason:** The message from the API, or the error details

---

## 5. Verify Queue Assignment

1. In the **Care Benefit Verify Requests** list view, add the **Owner** column if not visible.
2. The request should be assigned to the queue for its **Service Type**: Consultation → Consultation Care Queue, Infusion → Infusion Care Queue, Surgery → Surgery Care Queue. "Other" stays with the creator.

---

## 6. Verify Coverage Benefit Creation (API Response Simulation)

- (Optional, for full end-to-end test)
- POST the result to `/services/apexrest/care-benefit-verification-results/v1/` (Postman, or `scripts/apex/test.apex` with the request Id filled in).
- The endpoint returns `201` with the new `coverageBenefitId`, and the request becomes "Completed".
- Check the **Coverage Benefits** related list on the request.

---

## 7. Troubleshooting

- If you do not see expected results, refresh the page after 30–60 seconds.
- If fields are still not updating, contact your admin to check debug logs or API configuration.

---

## Ready to Demo!

You can now show:
- Creating all related records
- Submitting a benefit verification request
- Automatic status updates from the external API
- Queue assignment and record visibility

---

**For questions or issues, refer to the README or SETUP_GUIDE, or contact your Salesforce admin.** 