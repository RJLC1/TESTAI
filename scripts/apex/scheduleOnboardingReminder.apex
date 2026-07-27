String cron = '0 0 8 * * ?';
System.schedule('Daily Onboarding Kickoff Reminders', cron, new OnboardingReminderScheduler());
