import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import importContacts from '@salesforce/apex/CSVContactImportController.importContacts';

const FIELD_ALIASES = {
    title:        ['title', 'salutation'],
    firstname:    ['first name', 'firstname'],
    lastname:     ['last name', 'lastname', 'surname'],
    email:        ['email address', 'email'],
    mobile:       ['mobile number', 'mobile', 'phone'],
    company:      ['company name', 'company', 'organisation', 'organization'],
    campaignname: ['campaign name', 'campaign', 'event name', 'event'],
    startdate:    ['start date', 'event start', 'campaign start'],
    enddate:      ['end date', 'event end', 'campaign end'],
    campaigntype: ['type', 'campaign type', 'event type'],
};

const STATE = { IDLE: 'idle', PREVIEW: 'preview', IMPORTING: 'importing', DONE: 'done' };

export default class CsvContactImport extends LightningElement {
    @track state       = STATE.IDLE;
    @track previewRows = [];
    @track importResult;
    @track parseError;
    @track isDragging  = false;

    fileName   = '';
    csvContent = '';

    // ── State helpers ─────────────────────────────────────────────────────────
    get isIdle()      { return this.state === STATE.IDLE; }
    get isPreview()   { return this.state === STATE.PREVIEW; }
    get isImporting() { return this.state === STATE.IMPORTING; }
    get isDone()      { return this.state === STATE.DONE; }

    get dropZoneClass() {
        return `drop-zone slds-align_absolute-center slds-p-around_large${this.isDragging ? ' dragging' : ''}`;
    }

    get resultBannerClass() {
        const base = 'slds-notify slds-notify_alert slds-m-bottom_small';
        return this.importResult?.success ? `${base} slds-theme_success` : `${base} slds-theme_error`;
    }

    get resultIcon()    { return this.importResult?.success ? 'utility:success' : 'utility:error'; }
    get resultStatusText() { return this.importResult?.success ? 'Success' : 'Error'; }
    get hasRowErrors()  { return this.importResult?.rowErrors?.length > 0; }
    get hasSummary()    { return this.importResult?.success; }

    // ── File handling ─────────────────────────────────────────────────────────
    handleFileSelect(event) {
        const file = event.target.files[0];
        if (file) this.processFile(file);
    }

    handleDragOver(event)  { event.preventDefault(); this.isDragging = true; }
    handleDragLeave()      { this.isDragging = false; }
    handleDrop(event) {
        event.preventDefault();
        this.isDragging = false;
        const file = event.dataTransfer.files[0];
        if (file) this.processFile(file);
    }

    processFile(file) {
        this.parseError = null;
        if (!file.name.toLowerCase().endsWith('.csv')) {
            this.parseError = 'Please upload a .csv file.';
            return;
        }
        this.fileName = file.name;
        const reader  = new FileReader();
        reader.onload = (e) => {
            const rows = this.parseCSVClientSide(e.target.result);
            if (rows.length === 0) { this.parseError = 'No data rows found. Please check the file.'; return; }
            this.csvContent  = e.target.result;
            this.previewRows = rows.map((r, i) => ({ ...r, key: i }));
            this.state       = STATE.PREVIEW;
        };
        reader.onerror = () => { this.parseError = 'Failed to read the file. Please try again.'; };
        reader.readAsText(file);
    }

    // ── Client-side CSV parser (preview only) ─────────────────────────────────
    parseCSVClientSide(csv) {
        const lines = csv.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
        if (lines.length < 2) return [];

        const rawHeaders      = this.splitLine(lines[0]);
        const canonicalHeaders = rawHeaders.map(h => this.canonicalise(h.trim().toLowerCase()));
        const emptyRow        = { title:'', firstname:'', lastname:'', email:'', mobile:'', company:'', campaignname:'', startdate:'', enddate:'', campaigntype:'' };

        const rows = [];
        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            const values = this.splitLine(line);
            const row    = { ...emptyRow };
            canonicalHeaders.forEach((canon, j) => {
                if (canon && row.hasOwnProperty(canon)) row[canon] = (values[j] ?? '').trim();
            });
            rows.push(row);
        }
        return rows;
    }

    canonicalise(header) {
        for (const [field, aliases] of Object.entries(FIELD_ALIASES)) {
            if (aliases.includes(header)) return field;
        }
        return header;
    }

    splitLine(line) {
        const fields = [];
        let field = '', inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') { field += '"'; i++; }
                else inQuotes = !inQuotes;
            } else if (ch === ',' && !inQuotes) {
                fields.push(field); field = '';
            } else {
                field += ch;
            }
        }
        fields.push(field);
        return fields;
    }

    // ── Import ────────────────────────────────────────────────────────────────
    async handleImport() {
        this.state = STATE.IMPORTING;
        try {
            const result = await importContacts({ csvContent: this.csvContent });
            this.importResult = result;
            this.state        = STATE.DONE;
            this.dispatchEvent(new ShowToastEvent({
                title:   result.success ? 'Import successful' : 'Import completed with errors',
                message: result.message,
                variant: result.success ? 'success' : 'warning',
            }));
        } catch (error) {
            this.importResult = { success: false, message: error?.body?.message ?? 'An unexpected error occurred.', rowErrors: [] };
            this.state = STATE.DONE;
        }
    }

    // ── Reset ─────────────────────────────────────────────────────────────────
    handleReset() {
        this.state = STATE.IDLE; this.previewRows = []; this.csvContent = '';
        this.fileName = ''; this.parseError = null; this.importResult = null; this.isDragging = false;
    }
}
