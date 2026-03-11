public with sharing class CSVContactImportController {

    private static final Map<String, String> SALUTATION_MAP = new Map<String, String>{
        'mr'   => 'Mr.',
        'mr.'  => 'Mr.',
        'mrs'  => 'Mrs.',
        'mrs.' => 'Mrs.',
        'ms'   => 'Ms.',
        'ms.'  => 'Ms.',
        'dr'   => 'Dr.',
        'dr.'  => 'Dr.',
        'prof' => 'Prof.'
    };

    // Flexible header aliases — keys are normalised CSV header text, values are canonical field names
    private static final Map<String, String> HEADER_ALIAS_MAP = new Map<String, String>{
        'title'           => 'title',
        'salutation'      => 'title',
        'first name'      => 'firstname',
        'firstname'       => 'firstname',
        'last name'       => 'lastname',
        'lastname'        => 'lastname',
        'surname'         => 'lastname',
        'email address'   => 'email',
        'email'           => 'email',
        'mobile number'   => 'mobile',
        'mobile'          => 'mobile',
        'phone'           => 'mobile',
        'company name'    => 'company',
        'company'         => 'company',
        'organisation'    => 'company',
        'organization'    => 'company',
        'campaign name'   => 'campaignname',
        'campaign'        => 'campaignname',
        'event name'      => 'campaignname',
        'event'           => 'campaignname',
        'start date'      => 'startdate',
        'event start'     => 'startdate',
        'campaign start'  => 'startdate',
        'end date'        => 'enddate',
        'event end'       => 'enddate',
        'campaign end'    => 'enddate',
        'type'            => 'campaigntype',
        'campaign type'   => 'campaigntype',
        'event type'      => 'campaigntype'
    };

    /**
     * Main entry point called from the LWC.
     * Campaign details (name, start date, end date, type) are embedded in the CSV rows.
     * Each row may belong to a different campaign; contacts are linked as CampaignMembers
     * to whichever campaign is named in their row.
     *
     * @param csvContent  Raw CSV string (read client-side).
     */
    @AuraEnabled
    public static ImportResult importContacts(String csvContent) {
        ImportResult result = new ImportResult();

        try {
            List<Map<String, String>> rows = parseCSV(csvContent);

            if (rows.isEmpty()) {
                result.message = 'No data rows found in the CSV file.';
                return result;
            }

            // ── 1. Collect unique companies, emails, and campaign data ────────
            Set<String> companyNames = new Set<String>();
            Set<String> emails       = new Set<String>();

            for (Map<String, String> row : rows) {
                String company = row.get('company');
                String email   = row.get('email');
                if (!String.isBlank(company)) companyNames.add(company.trim());
                if (!String.isBlank(email))   emails.add(email.trim().toLowerCase());
            }

            // ── 2. Resolve / create Accounts ─────────────────────────────────
            Map<String, Id> accountIdByName = resolveAccounts(companyNames);

            // ── 3. Resolve / create Campaigns from CSV rows ──────────────────
            Map<String, Id> campaignIdByName = resolveCampaigns(rows, result);

            // ── 4. Resolve existing Contacts by email ────────────────────────
            Map<String, Contact> existingByEmail = new Map<String, Contact>();
            for (Contact c : [
                SELECT Id, Email
                FROM Contact
                WHERE Email IN :emails
                WITH USER_MODE
            ]) {
                existingByEmail.put(c.Email.toLowerCase(), c);
            }

            // ── 5. Build Contact list ─────────────────────────────────────────
            List<Contact>            toUpsert          = new List<Contact>();
            List<String>             rowCampaignNames  = new List<String>();

            for (Map<String, String> row : rows) {
                String lastName  = safeGet(row, 'lastname');
                String firstName = safeGet(row, 'firstname');
                String email     = safeGet(row, 'email');
                String title     = safeGet(row, 'title');
                String mobile    = safeGet(row, 'mobile');
                String company   = safeGet(row, 'company');
                String campaign  = safeGet(row, 'campaignname');

                if (String.isBlank(lastName)) {
                    result.rowErrors.add('Skipped — Last Name is required. Row data: ' + row);
                    continue;
                }

                Contact c;
                if (!String.isBlank(email) && existingByEmail.containsKey(email.toLowerCase())) {
                    c = existingByEmail.get(email.toLowerCase());
                    result.updated++;
                } else {
                    c = new Contact();
                    result.created++;
                }

                c.LastName    = lastName;
                c.FirstName   = String.isBlank(firstName) ? null : firstName;
                c.Email       = String.isBlank(email)     ? null : email;
                c.MobilePhone = String.isBlank(mobile)    ? null : mobile;

                if (!String.isBlank(title)) {
                    String key = title.toLowerCase();
                    c.Salutation = SALUTATION_MAP.containsKey(key) ? SALUTATION_MAP.get(key) : null;
                }

                if (!String.isBlank(company) && accountIdByName.containsKey(company)) {
                    c.AccountId = accountIdByName.get(company);
                }

                toUpsert.add(c);
                rowCampaignNames.add(campaign);
            }

            if (!toUpsert.isEmpty()) {
                upsert as user toUpsert;
            }

            // ── 6. Create CampaignMembers per row ────────────────────────────
            result.campaignMembersAdded = addCampaignMembersPerRow(toUpsert, rowCampaignNames, campaignIdByName);

            result.success = true;
            result.message = String.format(
                'Import complete: {0} contact(s) created, {1} updated, {2} campaign(s) processed, {3} campaign member(s) added, {4} row error(s).',
                new List<Object>{
                    result.created, result.updated,
                    result.campaignsProcessed, result.campaignMembersAdded,
                    result.rowErrors.size()
                }
            );

        } catch (Exception e) {
            result.success = false;
            result.message = 'Import failed: ' + e.getMessage();
        }

        return result;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static Map<String, Id> resolveAccounts(Set<String> names) {
        Map<String, Id> idByName = new Map<String, Id>();
        if (names.isEmpty()) return idByName;

        for (Account a : [SELECT Id, Name FROM Account WHERE Name IN :names WITH USER_MODE]) {
            idByName.put(a.Name, a.Id);
        }

        List<Account> newAccounts = new List<Account>();
        for (String name : names) {
            if (!idByName.containsKey(name)) {
                newAccounts.add(new Account(Name = name));
            }
        }

        if (!newAccounts.isEmpty()) {
            insert as user newAccounts;
            for (Account a : newAccounts) {
                idByName.put(a.Name, a.Id);
            }
        }

        return idByName;
    }

    private static Map<String, Id> resolveCampaigns(List<Map<String, String>> rows, ImportResult result) {
        // Collect unique campaign data keyed by name (first occurrence wins for dates/type)
        Map<String, Map<String, String>> campaignDataByName = new Map<String, Map<String, String>>();
        for (Map<String, String> row : rows) {
            String name = safeGet(row, 'campaignname');
            if (!String.isBlank(name) && !campaignDataByName.containsKey(name)) {
                campaignDataByName.put(name, row);
            }
        }

        if (campaignDataByName.isEmpty()) return new Map<String, Id>();

        Map<String, Id> idByName = new Map<String, Id>();
        for (Campaign c : [
            SELECT Id, Name FROM Campaign WHERE Name IN :campaignDataByName.keySet() WITH USER_MODE
        ]) {
            idByName.put(c.Name, c.Id);
        }

        List<Campaign> toInsert = new List<Campaign>();
        for (String name : campaignDataByName.keySet()) {
            if (!idByName.containsKey(name)) {
                Map<String, String> data = campaignDataByName.get(name);
                Campaign c = new Campaign(Name = name, IsActive = true);
                String startDate     = safeGet(data, 'startdate');
                String endDate       = safeGet(data, 'enddate');
                String campaignType  = safeGet(data, 'campaigntype');
                try { if (!String.isBlank(startDate))    c.StartDate = Date.valueOf(startDate); } catch (Exception e) {}
                try { if (!String.isBlank(endDate))      c.EndDate   = Date.valueOf(endDate);   } catch (Exception e) {}
                if (!String.isBlank(campaignType)) c.Type = campaignType;
                toInsert.add(c);
            }
        }

        if (!toInsert.isEmpty()) {
            insert as user toInsert;
            for (Campaign c : toInsert) {
                idByName.put(c.Name, c.Id);
            }
            result.campaignsCreated  += toInsert.size();
        }

        result.campaignsProcessed = idByName.size();
        return idByName;
    }

    private static Integer addCampaignMembersPerRow(
        List<Contact> contacts,
        List<String>  campaignNames,
        Map<String, Id> campaignIdByName
    ) {
        // Build a map of contactId → campaignId for new members only
        Map<Id, Id> contactToCampaign = new Map<Id, Id>();
        for (Integer i = 0; i < contacts.size(); i++) {
            String name = campaignNames[i];
            if (!String.isBlank(name) && campaignIdByName.containsKey(name) && contacts[i].Id != null) {
                contactToCampaign.put(contacts[i].Id, campaignIdByName.get(name));
            }
        }

        if (contactToCampaign.isEmpty()) return 0;

        // Exclude already-existing members
        Set<String> existingKeys = new Set<String>();
        for (CampaignMember cm : [
            SELECT ContactId, CampaignId FROM CampaignMember
            WHERE ContactId IN :contactToCampaign.keySet()
            WITH USER_MODE
        ]) {
            existingKeys.add(cm.ContactId + '_' + cm.CampaignId);
        }

        List<CampaignMember> toInsert = new List<CampaignMember>();
        for (Id contactId : contactToCampaign.keySet()) {
            Id campaignId = contactToCampaign.get(contactId);
            if (!existingKeys.contains(contactId + '_' + campaignId)) {
                toInsert.add(new CampaignMember(
                    ContactId  = contactId,
                    CampaignId = campaignId,
                    Status     = 'Responded'
                ));
            }
        }

        if (!toInsert.isEmpty()) insert as user toInsert;
        return toInsert.size();
    }

    /**
     * Parses a CSV string into a list of maps keyed by normalised canonical field names.
     * Handles quoted fields and Windows/Mac/Unix line endings.
     */
    @TestVisible
    private static List<Map<String, String>> parseCSV(String csv) {
        List<Map<String, String>> records = new List<Map<String, String>>();
        if (String.isBlank(csv)) return records;

        csv = csv.replace('\r\n', '\n').replace('\r', '\n');
        List<String> lines = csv.split('\n');
        if (lines.size() < 2) return records;

        // Map raw CSV headers → canonical names
        List<String> rawHeaders = splitCSVLine(lines[0]);
        List<String> canonicalHeaders = new List<String>();
        for (String h : rawHeaders) {
            String normalised = h.trim().toLowerCase();
            canonicalHeaders.add(HEADER_ALIAS_MAP.containsKey(normalised) ? HEADER_ALIAS_MAP.get(normalised) : normalised);
        }

        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) continue;

            List<String> values = splitCSVLine(line);
            Map<String, String> row = new Map<String, String>();
            for (Integer j = 0; j < canonicalHeaders.size(); j++) {
                row.put(canonicalHeaders[j], j < values.size() ? values[j].trim() : '');
            }
            records.add(row);
        }

        return records;
    }

    private static List<String> splitCSVLine(String line) {
        List<String> fields = new List<String>();
        String field = '';
        Boolean inQuotes = false;

        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {
                    field += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ',' && !inQuotes) {
                fields.add(field);
                field = '';
            } else {
                field += ch;
            }
        }
        fields.add(field);
        return fields;
    }

    private static String safeGet(Map<String, String> row, String key) {
        String val = row.get(key);
        return String.isBlank(val) ? '' : val.trim();
    }

    // ── Result wrapper ────────────────────────────────────────────────────────

    public class ImportResult {
        @AuraEnabled public Boolean      success              = false;
        @AuraEnabled public String       message              = '';
        @AuraEnabled public Integer      created              = 0;
        @AuraEnabled public Integer      updated              = 0;
        @AuraEnabled public Integer      campaignsProcessed   = 0;
        @AuraEnabled public Integer      campaignsCreated     = 0;
        @AuraEnabled public Integer      campaignMembersAdded = 0;
        @AuraEnabled public List<String> rowErrors            = new List<String>();
    }
}
