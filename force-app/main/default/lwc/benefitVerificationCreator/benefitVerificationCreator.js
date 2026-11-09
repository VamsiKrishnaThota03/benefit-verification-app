import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const OBJECT_API_NAME = 'CareBenefitVerifyRequest__c';

export default class BenefitVerificationCreator extends NavigationMixin(LightningElement) {
    isSubmitting = false;
    error;
    lastCreatedId;
    lastCreatedUrl;

    handleSubmit(event) {
        event.preventDefault();
        this.error = undefined;
        this.lastCreatedId = undefined;
        const fields = { ...event.detail.fields, Status__c: 'Submitted' };
        this.isSubmitting = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        this.isSubmitting = false;
        this.lastCreatedId = event.detail.id;
        this[NavigationMixin.GenerateUrl](this.recordPageRef(this.lastCreatedId)).then((url) => {
            this.lastCreatedUrl = url;
        });
        this.showToast('Request submitted', 'The benefit verification request was created and sent for verification.', 'success');
        this.resetFields();
    }

    handleError(event) {
        this.isSubmitting = false;
        const detail = event.detail || {};
        this.error = detail.detail || detail.message || 'The request could not be saved.';
        this.showToast('Error creating request', this.error, 'error');
    }

    handleReset() {
        this.error = undefined;
        this.lastCreatedId = undefined;
        this.resetFields();
    }

    handleViewRecord(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate](this.recordPageRef(this.lastCreatedId));
    }

    recordPageRef(recordId) {
        return {
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: OBJECT_API_NAME, actionName: 'view' }
        };
    }

    resetFields() {
        this.template.querySelectorAll('lightning-input-field').forEach((field) => field.reset());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
