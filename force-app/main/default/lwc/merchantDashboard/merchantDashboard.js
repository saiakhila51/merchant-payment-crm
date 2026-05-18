import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Apex imports — always import individually
import getActiveMerchants from '@salesforce/apex/MerchantController.getActiveMerchants';
import getMerchantStats   from '@salesforce/apex/MerchantController.getMerchantStats';

// ─── TABLE COLUMNS ───
// Defined outside class — doesn't need to be reactive
const COLUMNS = [
    {
        label: 'Business Name',
        fieldName: 'recordLink',      // will be URL
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Business_Name__c' },
            target: '_blank'
        },
        sortable: true
    },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }  // dynamic CSS
        }
    },
    {
        label: 'Category',
        fieldName: 'Merchant_Category__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Risk Score',
        fieldName: 'Risk_Score__c',
        type: 'number',
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'KYC',
        fieldName: 'KYC_Verified__c',
        type: 'boolean'
    },
    {
        label: 'Total Requests',
        fieldName: 'Total_Payment_Requests__c',
        type: 'number',
        sortable: true
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Details', name: 'view' },
                { label: 'View Payments', name: 'payments' },
                { label: 'Flag Risk',     name: 'flag' }
            ]
        }
    }
];

export default class MerchantDashboard extends NavigationMixin(LightningElement) {

    // ─── STATE ───
    @track merchants       = [];
    @track filteredMerchants = [];
    @track stats           = null;
    @track selectedMerchantId = null;
    @track isLoading       = true;
    @track errorMessage    = '';
    @track searchTerm      = '';
    @track sortedBy        = 'Business_Name__c';
    @track sortedDirection = 'asc';
    @track selectedFilter  = 'All'; 
    columns   = COLUMNS;
    rowOffset = 0;
    // Combobox options — defined as getter so it's clean
get filterOptions() {
    return [
        { label: 'All',       value: 'All' },
        { label: 'Active',    value: 'Active' },
        { label: 'Suspended', value: 'Suspended' },
        { label: 'High Risk', value: 'HighRisk' }
    ];
}

    // ─── COMPUTED PROPERTIES ───
    // These run every render — like getters in Vue
    get hasMerchants() {
        return this.filteredMerchants &&
               this.filteredMerchants.length > 0;
    }

    get hasError() {
        return this.errorMessage !== '';
    }

    // ─── WIRE — AUTO-FETCH STATS ───
    @wire(getMerchantStats)
    wiredStats({ error, data }) {
        if (data) {
            this.stats = data;
        }
        if (error) {
            console.error('Stats error:', error);
        }
    }

    // ─── WIRE — AUTO-FETCH MERCHANTS ───
    @wire(getActiveMerchants)
    wiredMerchants({ error, data }) {
        this.isLoading = false;

        if (data) {
            // Process data — add computed fields
            this.merchants = data.map(merchant => ({
                ...merchant,

                // Build record URL for clickable name
                recordLink: `/lightning/r/Merchant__c/${merchant.Id}/view`,

                // Dynamic CSS class based on status
                statusClass: this.getStatusClass(merchant.Status__c)
            }));

            // Initialize filtered list
            this.filteredMerchants = [...this.merchants];
            this.errorMessage = '';
        }

        if (error) {
            this.errorMessage = error.body?.message ||
                                'Failed to load merchants.';
            console.error('Merchant load error:', error);
        }
    }

    // ─── SEARCH HANDLER ───
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilter();
    }

    handleFilter(event) {
    this.selectedFilter = event.detail.value;
    this.applyFilter();
}
    applyFilter() {
    let result = [...this.merchants];

    // ── STEP 1: Apply status/risk filter ──
    if (this.selectedFilter !== 'All') {
        result = result.filter(m => {
            if (this.selectedFilter === 'HighRisk') {
                return m.Risk_Score__c >= 70;
            }
            return m.Status__c === this.selectedFilter;
        });
    }

    // ── STEP 2: Apply search on top of filtered result ──
    if (this.searchTerm) {
        result = result.filter(m =>
            (m.Business_Name__c &&
             m.Business_Name__c.toLowerCase()
              .includes(this.searchTerm)) ||
            (m.Merchant_Category__c &&
             m.Merchant_Category__c.toLowerCase()
              .includes(this.searchTerm))
        );
    }

    this.filteredMerchants = result;
}

    // ─── SORT HANDLER ───
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy        = fieldName;
        this.sortedDirection = sortDirection;

        // Sort the data
        const sorted = [...this.filteredMerchants].sort((a, b) => {
            const valA = a[fieldName] || '';
            const valB = b[fieldName] || '';

            let comparison = 0;
            if (valA > valB) comparison = 1;
            if (valA < valB) comparison = -1;

            return sortDirection === 'asc' ? comparison : -comparison;
        });

        this.filteredMerchants = sorted;
    }

    // ─── ROW ACTION HANDLER ───
    handleRowAction(event) {
        const action   = event.detail.action;
        const merchant = event.detail.row;

        switch (action.name) {
            case 'view':
                this.navigateToRecord(merchant.Id);
                break;
            case 'payments':
                 // Show payment list for selected merchant
                this.selectedMerchantId = merchant.Id;
                break;
                // Day 6: will navigate to payment dashboard
                break;
            case 'flag':
                this.showToast(
                    'Warning',
                    `${merchant.Business_Name__c} flagged for review`,
                    'warning'
                );
                break;
            default:
                break;
        }
    }

    // ─── ADD MERCHANT ───
    handleAddMerchant() {
        // Navigate to new merchant record form
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Merchant__c',
                actionName: 'new'
            }
        });
    }

    // ─── NAVIGATE TO RECORD ───
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Merchant__c',
                actionName: 'view'
            }
        });
    }

    // ─── TOAST NOTIFICATIONS ───
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant   // success | error | warning | info
        }));
    }

    // ─── HELPER: STATUS CSS CLASS ───
    getStatusClass(status) {
        const classMap = {
            'Active'    : 'status-active',
            'Suspended' : 'status-suspended',
            'Inactive'  : 'status-inactive'
        };
        return classMap[status] || '';
    }
}