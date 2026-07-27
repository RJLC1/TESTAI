# Customer Onboarding Readiness Tracker

Deployable Salesforce DX metadata for a new Enterprise org.

## Components
- `Onboarding__c` custom object and fields
- Bulk-safe Apex status/task automation and tests
- Daily scheduled reminder with custom desktop/mobile notification
- Lightning record page with readiness LWC, record details, and related activities
- Layout, list views, tab, and permission set

## Deploy
```bash
sf org login web --alias targetOrg
sf project deploy start --manifest manifest/package.xml --target-org targetOrg --test-level RunLocalTests
sf apex run --file scripts/apex/scheduleOnboardingReminder.apex --target-org targetOrg
sf org assign permset --name Customer_Success_Onboarding --target-org targetOrg
```

## Logic
- Unless manually set to **Kickoff Completed**, status is recalculated before save.
- **Ready for Kickoff** requires all three checkboxes, kickoff date, and implementation owner.
- The first transition to ready creates one high-priority Task owned by the implementation owner.
- A persistent flag prevents duplicates even if the record later moves out of and back into ready.
- Task completion/reopening is reflected on the onboarding record.
- The daily scheduler sends one custom notification per kickoff date when the date is today through seven days away and status is not completed.

## Assumptions
- **Kickoff Completed** is a deliberate user-selected terminal status; it is not inferred from the date.
- “Business days” means Monday-Friday. Company holidays are not excluded. Replace the helper with BusinessHours-based logic if holiday calendars must be honored.
- The reminder is sent once for each distinct kickoff date. Changing the kickoff date makes the record eligible for a new reminder.
- Reminder window includes today and the next seven calendar days.
- Task Status values `Not Started`, `In Progress`, and `Completed` are available in a standard Enterprise org.

## Admin maintenance
- Readiness conditions are centralized in `OnboardingAutomationService.isReady`.
- Reminder timing is centralized in `OnboardingReminderScheduler` and the cron script.
- UI labels and fields can be adjusted in Lightning App Builder after deployment.
