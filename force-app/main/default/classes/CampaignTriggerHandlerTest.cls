@IsTest
private class CampaignTriggerHandlerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Campaign buildCampaign(Date startDate, Date endDate) {
        return new Campaign(
            Name      = 'Test Campaign',
            IsActive  = true,
            StartDate = startDate,
            EndDate   = endDate
        );
    }

    // ── Rule 1: Start Date must be in the future ──────────────────────────────

    @IsTest
    static void testInsert_pastStartDate_fails() {
        Campaign c = buildCampaign(Date.today().addDays(-1), Date.today().addDays(5));
        Test.startTest();
        try {
            insert c;
            System.assert(false, 'Expected DmlException for past start date');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Start Date must be in the future'),
                'Wrong error message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testInsert_todayStartDate_fails() {
        Campaign c = buildCampaign(Date.today(), Date.today().addDays(5));
        Test.startTest();
        try {
            insert c;
            System.assert(false, 'Expected DmlException for today start date');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Start Date must be in the future'),
                'Wrong error message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testInsert_futureStartDate_succeeds() {
        Campaign c = buildCampaign(Date.today().addDays(1), Date.today().addDays(5));
        Test.startTest();
        insert c;
        Test.stopTest();
        System.assertNotEquals(null, c.Id, 'Campaign should have been inserted');
    }

    @IsTest
    static void testUpdate_changeStartDateToPast_fails() {
        Campaign c = buildCampaign(Date.today().addDays(3), Date.today().addDays(7));
        insert c;
        c.StartDate = Date.today().addDays(-1);
        Test.startTest();
        try {
            update c;
            System.assert(false, 'Expected DmlException for past start date on update');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Start Date must be in the future'),
                'Wrong error message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testInsert_nullStartDate_noError() {
        Campaign c = new Campaign(Name = 'No Dates Campaign', IsActive = true);
        Test.startTest();
        insert c;
        Test.stopTest();
        System.assertNotEquals(null, c.Id, 'Campaign with no dates should insert fine');
    }

    // ── Rule 2: End Date cannot be earlier than Start Date ────────────────────

    @IsTest
    static void testInsert_endBeforeStart_fails() {
        Campaign c = buildCampaign(Date.today().addDays(5), Date.today().addDays(2));
        Test.startTest();
        try {
            insert c;
            System.assert(false, 'Expected DmlException for end date before start date');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('End Date cannot be earlier than Start Date'),
                'Wrong error message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testInsert_endEqualsStart_succeeds() {
        Date future = Date.today().addDays(5);
        Campaign c = buildCampaign(future, future);
        Test.startTest();
        insert c;
        Test.stopTest();
        System.assertNotEquals(null, c.Id, 'Same start and end date should be valid');
    }

    @IsTest
    static void testInsert_endAfterStart_succeeds() {
        Campaign c = buildCampaign(Date.today().addDays(2), Date.today().addDays(10));
        Test.startTest();
        insert c;
        Test.stopTest();
        System.assertNotEquals(null, c.Id, 'End after start should be valid');
    }

    @IsTest
    static void testInsert_nullEndDate_noError() {
        Campaign c = buildCampaign(Date.today().addDays(3), null);
        Test.startTest();
        insert c;
        Test.stopTest();
        System.assertNotEquals(null, c.Id, 'Null end date should be valid');
    }

    // ── Both rules violated on same record ───────────────────────────────────

    @IsTest
    static void testInsert_bothRulesViolated_insertFails() {
        // Past start date AND end before start — insert must be rejected.
        // Note: Salesforce DmlException only surfaces the first field-level error
        // per record, so we assert on the start date error (Rule 1, evaluated first).
        Campaign c = buildCampaign(Date.today().addDays(-3), Date.today().addDays(-5));
        Test.startTest();
        try {
            insert c;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(
                e.getDmlMessage(0).contains('Start Date must be in the future'),
                'Expected start date error. Got: ' + e.getDmlMessage(0)
            );
        }
        Test.stopTest();
    }

    // ── Bulk: 200 records ─────────────────────────────────────────────────────

    @IsTest
    static void testBulkInsert_allValid() {
        List<Campaign> campaigns = new List<Campaign>();
        for (Integer i = 1; i <= 200; i++) {
            campaigns.add(buildCampaign(Date.today().addDays(i), Date.today().addDays(i + 2)));
        }
        Test.startTest();
        insert campaigns;
        Test.stopTest();
        System.assertEquals(200, [SELECT COUNT() FROM Campaign]);
    }
}
