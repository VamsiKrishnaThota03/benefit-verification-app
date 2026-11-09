/**
 * Response body returned by the external benefit verification API.
 * status and statusReason are always expected; the benefit fields are optional
 * and, when present, let the callout record the CoverageBenefit__c directly.
 */
public class BenefitVerificationResponse {
    @AuraEnabled public String status;
    @AuraEnabled public String statusReason;
    @AuraEnabled public String benefitStatus;
    @AuraEnabled public Decimal copay;
    @AuraEnabled public Decimal deductible;
    @AuraEnabled public Boolean isCovered;

    /** True when the API returned enough detail to create a CoverageBenefit__c. */
    public Boolean hasBenefitDetails() {
        return String.isNotBlank(benefitStatus)
            && (copay != null || deductible != null || isCovered != null);
    }
}
