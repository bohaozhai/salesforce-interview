# CSV Contact Import

A Salesforce Lightning Web Component that allows sales users to import event participants from a CSV file. On upload, the component automatically creates or updates **Contacts**, **Accounts**, and **Campaigns**, and links each contact to their campaign as a **CampaignMember**.

---

## Features

- Drag-and-drop or browse CSV file upload
- Client-side preview of parsed rows before committing
- Upserts Contacts by email (creates new, updates existing)
- Creates Accounts by company name (reused if already exists)
- Creates Campaigns from CSV data (reused if name already exists)
- Links Contacts to their Campaign as `CampaignMember` (Status: `Responded`)
- Flexible header names — see [Supported Column Headers](#supported-column-headers)
- Result summary showing contacts created/updated, campaigns created, members linked
- Available as a tab in the **Cartology Sales** app

---

## CSV Format

The file must be a comma-separated `.csv` file with a header row. Column order does not matter. All headers are case-insensitive.

### Example

```csv
Title, First Name, Last Name, Email Address, Mobile Number, Company Name, Campaign Name, Start Date,  End Date,   Type
Mr.,   John,       Smith,     john@co.com,   0412345678,    Acme Corp,    Summer Conf,   2026-04-01, 2026-04-03, Conference
Ms.,   Jane,       Doe,       jane@co.com,   0498765432,    Beta Ltd,     Winter Expo,   2026-06-10, 2026-06-12, Seminar
```

### Field Reference

#### Contact Fields

| Column Header | Alternate Headers | Required | Notes |
|---|---|---|---|
| `Last Name` | `Lastname`, `Surname` | ✅ | Row is skipped if blank |
| `First Name` | `Firstname` | | |
| `Title` | `Salutation` | | Mapped to Salesforce Salutation picklist: `Mr.`, `Mrs.`, `Ms.`, `Dr.`, `Prof.` |
| `Email Address` | `Email` | | Used to match existing contacts (upsert key) |
| `Mobile Number` | `Mobile`, `Phone` | | |
| `Company Name` | `Company`, `Organisation`, `Organization` | | Creates or reuses an Account |

#### Campaign Fields

| Column Header | Alternate Headers | Required | Notes |
|---|---|---|---|
| `Campaign Name` | `Campaign`, `Event Name`, `Event` | | If blank, contact is created without a campaign link |
| `Start Date` | `Event Start`, `Campaign Start` | | Format: `YYYY-MM-DD`. Must be a future date |
| `End Date` | `Event End`, `Campaign End` | | Format: `YYYY-MM-DD`. Must not be before Start Date |
| `Type` | `Campaign Type`, `Event Type` | | e.g. `Conference`, `Webinar`, `Seminar` |

---

## Business Rules

The following rules are enforced by an Apex trigger (`CampaignTrigger`) and apply globally to **all** Campaign records — both via CSV import and manual record creation.

| Rule | Detail |
|---|---|
| Start Date must be in the future | `StartDate` must be strictly greater than today |
| End Date cannot precede Start Date | `EndDate` must be greater than or equal to `StartDate` |

If a CSV row contains campaign dates that violate these rules, the entire import will fail and an error message will be returned to the user.

---

## How to Use

1. Navigate to the **Cartology Sales** app
2. Click the **Import Contacts** tab
3. Drag and drop your `.csv` file onto the upload area, or click **Browse File**
4. Review the preview table to confirm the parsed data
5. Click **Import**
6. Review the result summary — any skipped rows will be listed with a reason

---

## Component Details

### LWC: `csvContactImport`

| Property | Value |
|---|---|
| Component name | `csvContactImport` |
| API version | 63.0 |
| Target pages | `lightning__AppPage`, `lightning__RecordPage`, `lightning__HomePage` |

The component reads the CSV file client-side (no intermediate file storage) and sends the raw content string to the Apex controller for processing.

### Apex: `CSVContactImportController`

| Method | Description |
|---|---|
| `importContacts(String csvContent)` | Parses CSV, upserts Accounts, upserts Contacts, creates Campaigns, inserts CampaignMembers. Returns an `ImportResult` with counts and row errors. |

### Apex: `CampaignTriggerHandler`

| Method | Description |
|---|---|
| `validate(List<Campaign> campaigns)` | Called by `CampaignTrigger` on `before insert` and `before update`. Enforces start date and end date business rules. |

---

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── CSVContactImportController.cls
│   ├── CSVContactImportControllerTest.cls
│   ├── CampaignTriggerHandler.cls
│   └── CampaignTriggerHandlerTest.cls
├── triggers/
│   └── CampaignTrigger.trigger
├── lwc/
│   └── csvContactImport/
│       ├── csvContactImport.html
│       ├── csvContactImport.js
│       ├── csvContactImport.css
│       └── csvContactImport.js-meta.xml
├── applications/
│   └── Cartology_Sales.app-meta.xml
├── flexipages/
│   └── CSV_Contact_Import.flexipage-meta.xml
└── tabs/
    └── CSV_Contact_Import.tab-meta.xml
```

---

## Test Coverage

| Class | Tests | Result |
|---|---|---|
| `CSVContactImportControllerTest` | 11 | ✅ All pass |
| `CampaignTriggerHandlerTest` | 11 | ✅ All pass |

Run tests against the scratch org:

```bash
# All local tests
sf apex run test --test-level RunLocalTests --target-org dev --result-format human --synchronous

# Specific class
sf apex run test --class-names CSVContactImportControllerTest --target-org dev --result-format human --synchronous
sf apex run test --class-names CampaignTriggerHandlerTest --target-org dev --result-format human --synchronous
```

---

## Deployment

```bash
# Deploy all components
sf project deploy start --target-org dev

# Deploy specific components only
sf project deploy start \
  --metadata "ApexClass:CSVContactImportController" \
  --metadata "ApexClass:CSVContactImportControllerTest" \
  --metadata "LightningComponentBundle:csvContactImport" \
  --target-org dev

# Deploy trigger only
sf project deploy start \
  --metadata "ApexTrigger:CampaignTrigger" \
  --metadata "ApexClass:CampaignTriggerHandler" \
  --metadata "ApexClass:CampaignTriggerHandlerTest" \
  --target-org dev
```
