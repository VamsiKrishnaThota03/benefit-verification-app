import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BenefitVerificationCreator extends LightningElement {
    @track isSubmitting = false;
    @track error;

    handleSuccess(event) {
        this.isSubmitting = false;
        this.error = undefined;
        this.showToast('Success', 'Benefit Verification Request created!', 'success');
        // Optionally, reset the form or navigate to the new record
    }

    handleError(event) {
        this.isSubmitting = false;
        this.error = event.detail.message;
        this.showToast('Error Creating Request', this.error, 'error');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}
