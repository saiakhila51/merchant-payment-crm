import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getRequestsForMerchant from
    '@salesforce/apex/PaymentRequestController.getRequestsForMerchant';
import updateRequestStatus from
    '@salesforce/apex/PaymentRequestController.updateRequestStatus';

// ─── TABLE COLUMNS ───
const COLUMNS = [
    {
        label    : 'Request Name',
        fieldName: 'Name',
        type     : 'text',
        sortable : true
    },
    {
        label    : 'Amount (₹)',
        fieldName: 'Amount__c',
        type     : 'currency',
        typeAttributes: { currencyCode: 'INR' },
        sortable : true
    },
    {
        label    : 'Status',
        fieldName: 'Status__c',
        type     : 'text',
        cellAttributes: {
            class: { fieldName: 'statusBadgeClass' }
        }
    },
    {
        label    : 'Due Date',
        fieldName: 'Due_Date__c',
        type     : 'date',
        sortable : true
    },
    {
        label    : 'Attempts',
        fieldName: 'Attempts__c',
        type     : 'number'
    },
    {
        label    : 'Customer',
        fieldName: 'CustomerName',
        type     : 'text'
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Mark as Paid',    name: 'mark_paid' },
                { label: 'Mark as Failed',  name: 'mark_failed' },
                { label: 'Mark as Expired', name: 'mark_expired' }
            ]
        }
    }
];

export default class PaymentRequestList extends LightningElement {

    // ─── FROM PARENT ───
    @api merchantId;

    // ─── STATE ───
    @track requests   = [];
    @track showForm   = false;
    @track isLoading  = true;

    columns = COLUMNS;

    // Store wire result for refreshApex
    wiredRequestsResult;

    // ─── COMPUTED: STATS ───
    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }

    get pendingCount() {
        return this.requests.filter(
            r => r.Status__c === 'Pending'
        ).length;
    }

    get paidCount() {
        return this.requests.filter(
            r => r.Status__c === 'Paid'
        ).length;
    }

    get failedCount() {
        return this.requests.filter(
            r => r.Status__c === 'Failed'
        ).length;
    }

    get totalAmount() {
        const total = this.requests.reduce(
            (sum, r) => sum + (r.Amount__c || 0), 0
        );
        // Format as Indian number
        return total.toLocaleString('en-IN');
    }

    // ─── WIRE: LOAD REQUESTS ───
    @wire(getRequestsForMerchant, { merchantId: '$merchantId' })
    wiredRequests(result) {
        // Store full result for refreshApex
        this.wiredRequestsResult = result;
        this.isLoading = false;

        if (result.data) {
            // Process data — flatten relationships
            this.requests = result.data.map(req => ({
                ...req,
                // Flatten related field for datatable
                CustomerName: req.Customer__r?.Name || '—',
                // Status badge CSS
                statusBadgeClass: this.getStatusClass(req.Status__c)
            }));
        }

        if (result.error) {
            console.error('Request load error:', result.error);
        }
    }

    // ─── TOGGLE FORM ───
    toggleForm() {
        this.showForm = !this.showForm;
    }

    // ─── CHILD EVENT: FORM SUBMITTED ───
    async handleRequestCreated(event) {
        // Hide form
        this.showForm = false;

        // Refresh wire data — clears cache and refetches
        await refreshApex(this.wiredRequestsResult);

        this.showToast(
            'Success',
            'Payment request created and list refreshed.',
            'success'
        );
    }

    // ─── CHILD EVENT: FORM CANCELLED ───
    handleFormCancelled() {
        this.showForm = false;
    }

    // ─── ROW ACTION: STATUS UPDATE ───
    async handleRowAction(event) {
        const action    = event.detail.action.name;
        const requestId = event.detail.row.Id;
        const rowName   = event.detail.row.Name;

        // Map action name to status value
        const statusMap = {
            'mark_paid'    : 'Paid',
            'mark_failed'  : 'Failed',
            'mark_expired' : 'Expired'
        };

        const newStatus = statusMap[action];
        if (!newStatus) return;

        try {
            // Imperative Apex call
            await updateRequestStatus({
                requestId : requestId,
                newStatus : newStatus
            });

            // Refresh list after update
            await refreshApex(this.wiredRequestsResult);

            this.showToast(
                'Updated',
                `${rowName} marked as ${newStatus}.`,
                'success'
            );

        } catch (error) {
            this.showToast(
                'Error',
                error.body?.message || 'Status update failed.',
                'error'
            );
        }
    }

    // ─── STATUS CSS ───
    getStatusClass(status) {
        const map = {
            'Pending'  : 'status-pending',
            'Paid'     : 'status-paid',
            'Failed'   : 'status-failed',
            'Refunded' : 'status-refunded',
            'Expired'  : 'status-expired'
        };
        return map[status] || '';
    }

    // ─── TOAST ───
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}