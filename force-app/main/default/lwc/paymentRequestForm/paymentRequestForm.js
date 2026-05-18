import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createPaymentRequest from
    '@salesforce/apex/PaymentRequestController.createPaymentRequest';
import getCustomersForMerchant from
    '@salesforce/apex/PaymentRequestController.getCustomersForMerchant';

export default class PaymentRequestForm extends LightningElement {

    // ─── RECEIVED FROM PARENT ───
    @api merchantId;

    // ─── LOCAL STATE ───
    @track formData = {
        amount      : '',
        dueDate     : '',
        customerId  : '',
        description : ''
    };

    @track isSubmitting   = false;
    @track validationError = '';
    @track customerOptions = [];

    // ─── COMPUTED ───
    get today() {
        // Min date for due date picker
        return new Date().toISOString().split('T')[0];
    }

    get submitLabel() {
        return this.isSubmitting ? 'Creating...' : 'Create Request';
    }

    // ─── WIRE: LOAD CUSTOMERS ───
    @wire(getCustomersForMerchant, { merchantId: '$merchantId' })
    wiredCustomers({ error, data }) {
        if (data) {
            // Map to combobox format
            this.customerOptions = [
                { label: '-- No Customer --', value: '' },
                ...data.map(c => ({
                    label : c.Name,
                    value : c.Id
                }))
            ];
        }
        if (error) {
            console.error('Customer load error:', error);
        }
    }

    // ─── FIELD CHANGE HANDLER ───
    // Single handler for all fields using data-field attribute
    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;

        // Spread operator keeps other fields intact
        this.formData = { ...this.formData, [field]: value };

        // Clear validation on change
        this.validationError = '';
    }

    // ─── VALIDATION ───
    validateForm() {
        if (!this.formData.amount || this.formData.amount <= 0) {
            this.validationError = 'Please enter a valid amount greater than 0.';
            return false;
        }

        if (!this.formData.dueDate) {
            this.validationError = 'Please select a due date.';
            return false;
        }

        const selectedDate = new Date(this.formData.dueDate);
        const todayDate    = new Date(this.today);
        if (selectedDate < todayDate) {
            this.validationError = 'Due date cannot be in the past.';
            return false;
        }

        if (!this.merchantId) {
            this.validationError = 'Merchant context is missing.';
            return false;
        }

        return true;
    }

    // ─── SUBMIT HANDLER ───
    async handleSubmit() {
        // Step 1: validate
        if (!this.validateForm()) return;

        this.isSubmitting = true;

        try {
            // Step 2: call Apex imperatively
            const newId = await createPaymentRequest({
                amount      : parseFloat(this.formData.amount),
                dueDate     : this.formData.dueDate,
                merchantId  : this.merchantId,
                customerId  : this.formData.customerId || null,
                description : this.formData.description
            });

            // Step 3: show success toast
            this.showToast(
                'Payment Request Created',
                'Request created successfully.',
                'success'
            );

            // Step 4: fire event to parent
            // Parent listens and refreshes its list
            this.dispatchEvent(new CustomEvent('requestcreated', {
                detail: { requestId: newId }
            }));

            // Step 5: reset form
            this.resetForm();

        } catch (error) {
            this.showToast(
                'Error',
                error.body?.message || 'Failed to create request.',
                'error'
            );
        } finally {
            // Always runs — re-enable button
            this.isSubmitting = false;
        }
    }

    // ─── CANCEL HANDLER ───
    handleCancel() {
        this.resetForm();
        // Notify parent to hide form
        this.dispatchEvent(new CustomEvent('formcancelled'));
    }

    // ─── RESET FORM ───
    resetForm() {
        this.formData = {
            amount      : '',
            dueDate     : '',
            customerId  : '',
            description : ''
        };
        this.validationError = '';
    }

    // ─── TOAST ───
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title, message, variant
        }));
    }
}