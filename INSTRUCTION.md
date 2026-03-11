# CSVContactImportControllerTest — Test Results

**Class:** `CSVContactImportControllerTest`
**Org:** `test-x8ztoh5bsa9m@example.com` (`00D8r00000Ae82jEAB`)
**Run Date:** 2026-03-11
**API Version:** 63.0

---

## Summary

| Metric | Value |
|---|---|
| Tests Ran | 11 |
| Passed | 5 |
| Failed | 6 |
| Pass Rate | 45% |
| Total Execution Time | 1256 ms |

---

## Test Results

| Test Name | Outcome | Runtime (ms) | Failure Message |
|---|---|---|---|
| `testEmptyCSV_returnsEarlyWithMessage` | ✅ Pass | 12 | |
| `testExistingCampaignMember_notDuplicated` | ✅ Pass | 265 | |
| `testExistingCampaign_usedNotDuplicated` | ✅ Pass | 141 | |
| `testHeadersOnly_returnsNoRows` | ✅ Pass | 13 | |
| `testRowWithNoCampaign_createsContactOnly` | ✅ Pass | 118 | |
| `testHappyPath_createsContactCampaignAndMember` | ❌ Fail | — | `Import failed: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Start Date must be in the future.: [StartDate]` |
| `testMultipleRowsMultipleCampaigns` | ❌ Fail | — | `Import failed: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Start Date must be in the future.: [StartDate]` |
| `testDuplicateEmail_updatesExistingContact` | ❌ Fail | — | `Assertion Failed` |
| `testMissingLastName_skipsRow` | ❌ Fail | — | `Assertion Failed: Expected: 1, Actual: 0` |
| `testQuotedFields_parsedCorrectly` | ❌ Fail | — | `Import failed: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Start Date must be in the future.: [StartDate]` |
| `testAlternateHeaders_resolvedCorrectly` | ❌ Fail | — | `Import failed: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Start Date must be in the future.: [StartDate]` |

---

## Root Cause

All 6 failures are caused by a **regression introduced by the `CampaignTrigger`**, which was added after this test class was written.

The trigger enforces that `Campaign.StartDate` must be strictly in the future (`StartDate > Date.today()`). The test data in `CSVContactImportControllerTest` uses hardcoded past dates (e.g. `2025-02-01`, `2025-03-01`) in the CSV campaign columns. When the controller attempts to insert these campaigns, the trigger rejects them with:

```
FIELD_CUSTOM_VALIDATION_EXCEPTION, Start Date must be in the future.: [StartDate]
```

---
