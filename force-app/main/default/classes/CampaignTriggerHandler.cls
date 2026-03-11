public with sharing class CampaignTriggerHandler {

    private static final String ERR_START_DATE_FUTURE =
        'Start Date must be in the future.';
    private static final String ERR_END_BEFORE_START =
        'End Date cannot be earlier than Start Date.';

    /**
     * Validates business rules on Campaign records before insert or update.
     * Errors are added directly to the offending field so they surface in
     * both the UI (record form) and API responses (including CSV import).
     *
     * Rules:
     *   1. StartDate must be strictly in the future (> today).
     *   2. EndDate, when provided, must be >= StartDate.
     */
    public static void validate(List<Campaign> campaigns) {
        Date today = Date.today();

        for (Campaign c : campaigns) {

            // Rule 1 — Start Date must be in the future
            if (c.StartDate != null && c.StartDate <= today) {
                c.StartDate.addError(ERR_START_DATE_FUTURE);
            }

            // Rule 2 — End Date cannot be earlier than Start Date
            if (c.StartDate != null && c.EndDate != null && c.EndDate < c.StartDate) {
                c.EndDate.addError(ERR_END_BEFORE_START);
            }
        }
    }
}
