@IsTest
private class CSVContactImportControllerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String buildCSV(List<List<String>> rows) {
        String header = 'Title,First Name,Last Name,Email Address,Mobile Number,Company Name,Campaign Name,Start Date,End Date,Type\n';
        List<String> lines = new List<String>();
        for (List<String> row : rows) lines.add(String.join(row, ','));
        return header + String.join(lines, '\n');
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void testHappyPath_createsContactCampaignAndMember() {
        String csv = buildCSV(new List<List<String>>{
            new List<String>{ 'Mr.','John','Smith','john@example.com','0412345678','Acme Corp','Summer Conf','2025-02-01','2025-02-03','Conference' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success, r.message);
        System.assertEquals(1, r.created);
        System.assertEquals(0, r.updated);
        System.assertEquals(1, r.campaignsCreated);
        System.assertEquals(1, r.campaignsProcessed);
        System.assertEquals(1, r.campaignMembersAdded);
        System.assertEquals(0, r.rowErrors.size());

        Contact c = [SELECT Salutation, FirstName, LastName, Email, MobilePhone, Account.Name FROM Contact LIMIT 1];
        System.assertEquals('Mr.',        c.Salutation);
        System.assertEquals('John',       c.FirstName);
        System.assertEquals('Smith',      c.LastName);
        System.assertEquals('Acme Corp',  c.Account.Name);

        Campaign camp = [SELECT Name, StartDate, EndDate, Type FROM Campaign LIMIT 1];
        System.assertEquals('Summer Conf',                   camp.Name);
        System.assertEquals(Date.newInstance(2025, 2, 1),   camp.StartDate);
        System.assertEquals(Date.newInstance(2025, 2, 3),   camp.EndDate);
        System.assertEquals('Conference',                    camp.Type);
    }

    @IsTest
    static void testMultipleRowsMultipleCampaigns() {
        String csv = buildCSV(new List<List<String>>{
            new List<String>{ 'Ms.','Alice','Brown','alice@example.com','0411111111','Alpha Ltd','Event A','2025-03-01','2025-03-02','Webinar' },
            new List<String>{ 'Dr.','Bob','Jones','bob@example.com','0422222222','Beta Inc','Event B','2025-04-01','2025-04-02','Seminar' },
            new List<String>{ '','Carol','Williams','carol@example.com','','Alpha Ltd','Event A','2025-03-01','2025-03-02','Webinar' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success, r.message);
        System.assertEquals(3, r.created);
        System.assertEquals(2, r.campaignsCreated,   'Two distinct campaigns');
        System.assertEquals(3, r.campaignMembersAdded);
        System.assertEquals(2, [SELECT COUNT() FROM Account], 'Alpha Ltd reused');
    }

    @IsTest
    static void testDuplicateEmail_updatesExistingContact() {
        Account acc = new Account(Name = 'Old Corp'); insert acc;
        Contact existing = new Contact(FirstName='Old', LastName='Name', Email='existing@example.com', AccountId=acc.Id);
        insert existing;

        String csv = buildCSV(new List<List<String>>{
            new List<String>{ 'Mr.','New','Name','existing@example.com','0499999999','New Corp','Conf 2025','2025-05-01','2025-05-02','Conference' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success);
        System.assertEquals(0, r.created);
        System.assertEquals(1, r.updated);
        System.assertEquals(1, r.campaignMembersAdded);

        Contact c = [SELECT FirstName, MobilePhone FROM Contact WHERE Id = :existing.Id];
        System.assertEquals('New',        c.FirstName);
        System.assertEquals('0499999999', c.MobilePhone);
    }

    @IsTest
    static void testRowWithNoCampaign_createsContactOnly() {
        String csv = buildCSV(new List<List<String>>{
            new List<String>{ '','Jane','Doe','jane@example.com','','Solo Inc','','','','' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success);
        System.assertEquals(1, r.created);
        System.assertEquals(0, r.campaignsCreated);
        System.assertEquals(0, r.campaignMembersAdded);
    }

    @IsTest
    static void testMissingLastName_skipsRow() {
        String csv = buildCSV(new List<List<String>>{
            new List<String>{ 'Mr.','NoSurname','','no@example.com','','Corp','Event','2025-01-01','2025-01-02','Other' },
            new List<String>{ '','Valid','Person','valid@example.com','','','','','','' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assertEquals(1, r.created);
        System.assertEquals(1, r.rowErrors.size());
    }

    @IsTest
    static void testEmptyCSV_returnsEarlyWithMessage() {
        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts('');
        Test.stopTest();

        System.assertEquals(0, r.created);
    }

    @IsTest
    static void testHeadersOnly_returnsNoRows() {
        String csv = 'Title,First Name,Last Name,Email Address,Mobile Number,Company Name,Campaign Name,Start Date,End Date,Type\n';
        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assertEquals(0, r.created);
    }

    @IsTest
    static void testQuotedFields_parsedCorrectly() {
        String csv = 'Title,First Name,Last Name,Email Address,Mobile Number,Company Name,Campaign Name,Start Date,End Date,Type\n'
                   + 'Ms.,Emma,Taylor,emma@example.com,0455555555,"Smith, Jones & Partners","Annual Gala, 2025","2025-06-01","2025-06-02","Other"\n';

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success, r.message);
        System.assertEquals(1, r.created);
        System.assertEquals('Smith, Jones & Partners', [SELECT Name FROM Account LIMIT 1].Name);
        System.assertEquals('Annual Gala, 2025',       [SELECT Name FROM Campaign LIMIT 1].Name);
    }

    @IsTest
    static void testAlternateHeaders_resolvedCorrectly() {
        String csv = 'Salutation,Firstname,Surname,Email,Phone,Company,Event Name,Event Start,Event End,Event Type\n'
                   + 'Dr.,David,Lee,david@example.com,0466666666,Lee Consulting,Tech Summit,2025-07-01,2025-07-03,Conference\n';

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success, r.message);
        System.assertEquals(1, r.created);
        System.assertEquals('Dr.', [SELECT Salutation FROM Contact LIMIT 1].Salutation);
        System.assertEquals('Tech Summit', [SELECT Name FROM Campaign LIMIT 1].Name);
    }

    @IsTest
    static void testExistingCampaignMember_notDuplicated() {
        Campaign camp = new Campaign(Name='Existing Conf', IsActive=true); insert camp;
        Account acc   = new Account(Name='Dup Corp'); insert acc;
        Contact con   = new Contact(FirstName='Re', LastName='Member', Email='remem@example.com', AccountId=acc.Id);
        insert con;
        insert new CampaignMember(CampaignId=camp.Id, ContactId=con.Id, Status='Sent');

        String csv = buildCSV(new List<List<String>>{
            new List<String>{ '','Re','Member','remem@example.com','','Dup Corp','Existing Conf','2025-01-01','2025-01-02','Conference' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success);
        System.assertEquals(0, r.campaignMembersAdded, 'Should not duplicate CampaignMember');
        System.assertEquals(1, [SELECT COUNT() FROM CampaignMember WHERE CampaignId=:camp.Id]);
    }

    @IsTest
    static void testExistingCampaign_usedNotDuplicated() {
        Campaign existing = new Campaign(Name='Pre-existing Event', IsActive=true, Type='Webinar');
        insert existing;

        String csv = buildCSV(new List<List<String>>{
            new List<String>{ '','Sam','Green','sam@example.com','','','Pre-existing Event','2025-08-01','2025-08-02','Webinar' }
        });

        Test.startTest();
        CSVContactImportController.ImportResult r = CSVContactImportController.importContacts(csv);
        Test.stopTest();

        System.assert(r.success);
        System.assertEquals(0, r.campaignsCreated,    'Existing campaign should not be re-created');
        System.assertEquals(1, r.campaignsProcessed);
        System.assertEquals(1, r.campaignMembersAdded);
        System.assertEquals(1, [SELECT COUNT() FROM Campaign WHERE Name='Pre-existing Event']);
    }
}
