# Implementation approach

## Data model
`Onboarding__c` stores the requested customer, contact, ownership, date, checklist, and status data. System fields prevent duplicate task/reminder actions and expose preparation completion.

## Status automation
A before-insert/before-update trigger recalculates status as Not Ready or Ready for Kickoff. A user can explicitly set Kickoff Completed; subsequent edits preserve it until the user changes the status.

## Kickoff task
An after-save handler detects the first transition to Ready for Kickoff, inserts the required Task, and sets a durable duplicate-prevention flag. The due date helper subtracts weekdays only.

## Reminder
`OnboardingReminderScheduler` is scheduled daily. It sends a Salesforce custom notification to the implementation owner when kickoff is within seven days and the onboarding is not completed. A date stamp prevents duplicate reminders for the same kickoff date.

## User experience
The custom Lightning record page places an Onboarding Readiness Panel near the top. It shows current status, missing requirements, each readiness criterion, and kickoff-task completion. Standard record details and activities remain available on the same page.

## Security
The included permission set grants CRUD/field access for Customer Success users. Internal automation fields are read-only.

## Operational step
A metadata deployment cannot create a scheduled Apex job. Run `scripts/apex/scheduleOnboardingReminder.apex` once after deployment.
