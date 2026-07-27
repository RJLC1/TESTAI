for (CronTrigger job : [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name = 'Daily Onboarding Kickoff Reminders']) { System.abortJob(job.Id); }
