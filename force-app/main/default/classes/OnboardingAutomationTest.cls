@IsTest
private class OnboardingAutomationTest {
    private static User implementationOwner() {
        return [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    }

    private static Onboarding__c readyOnboarding(Date kickoffDate, Id ownerId) {
        return new Onboarding__c(
            Customer_Name__c = 'Acme Customer',
            Contract_Signed__c = true,
            Welcome_Email_Sent__c = true,
            Initial_Data_Received__c = true,
            Kickoff_Date__c = kickoffDate,
            Implementation_Owner__c = ownerId,
            Status__c = 'Not Ready',
            Kickoff_Task_Created__c = false
        );
    }

    @IsTest
    static void readyOnboardingUpdatesStatusAndCreatesTask() {
        User owner = implementationOwner();
        Date kickoff = Date.newInstance(2026, 8, 27);
        Onboarding__c onboarding = readyOnboarding(kickoff, owner.Id);

        Test.startTest();
        insert onboarding;
        Test.stopTest();

        onboarding = [SELECT Id, Status__c, Kickoff_Task_Created__c FROM Onboarding__c WHERE Id = :onboarding.Id];
        System.assertEquals('Ready for Kickoff', onboarding.Status__c);
        System.assertEquals(true, onboarding.Kickoff_Task_Created__c);

        List<Task> tasks = [
            SELECT Subject, OwnerId, WhatId, Status, Priority, ActivityDate
            FROM Task
            WHERE WhatId = :onboarding.Id
        ];
        System.assertEquals(1, tasks.size());
        System.assertEquals('Prepare customer kickoff meeting', tasks[0].Subject);
        System.assertEquals(owner.Id, tasks[0].OwnerId);
        System.assertEquals(onboarding.Id, tasks[0].WhatId);
        System.assertEquals('Not Started', tasks[0].Status);
        System.assertEquals('High', tasks[0].Priority);
        System.assertEquals(kickoff.addDays(-2), tasks[0].ActivityDate);
    }

    @IsTest
    static void readinessRequiresEveryCriterion() {
        User owner = implementationOwner();
        Date kickoff = Date.today().addDays(10);
        List<Onboarding__c> records = new List<Onboarding__c>();

        records.add(new Onboarding__c(Customer_Name__c='Missing Contract', Welcome_Email_Sent__c=true, Initial_Data_Received__c=true, Kickoff_Date__c=kickoff, Implementation_Owner__c=owner.Id, Status__c='Not Ready'));
        records.add(new Onboarding__c(Customer_Name__c='Missing Welcome', Contract_Signed__c=true, Initial_Data_Received__c=true, Kickoff_Date__c=kickoff, Implementation_Owner__c=owner.Id, Status__c='Not Ready'));
        records.add(new Onboarding__c(Customer_Name__c='Missing Data', Contract_Signed__c=true, Welcome_Email_Sent__c=true, Kickoff_Date__c=kickoff, Implementation_Owner__c=owner.Id, Status__c='Not Ready'));
        records.add(new Onboarding__c(Customer_Name__c='Missing Date', Contract_Signed__c=true, Welcome_Email_Sent__c=true, Initial_Data_Received__c=true, Implementation_Owner__c=owner.Id, Status__c='Not Ready'));
        records.add(new Onboarding__c(Customer_Name__c='Missing Owner', Contract_Signed__c=true, Welcome_Email_Sent__c=true, Initial_Data_Received__c=true, Kickoff_Date__c=kickoff, Status__c='Not Ready'));

        Test.startTest();
        insert records;
        Test.stopTest();

        Set<Id> ids = new Map<Id, Onboarding__c>(records).keySet();
        for (Onboarding__c actual : [SELECT Id, Status__c, Kickoff_Task_Created__c FROM Onboarding__c WHERE Id IN :ids]) {
            System.assertEquals('Not Ready', actual.Status__c);
            System.assertEquals(false, actual.Kickoff_Task_Created__c);
        }
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId IN :ids]);
    }

    @IsTest
    static void existingTaskFlagPreventsDuplicateTask() {
        User owner = implementationOwner();
        Onboarding__c onboarding = readyOnboarding(Date.today().addDays(10), owner.Id);
        onboarding.Kickoff_Task_Created__c = true;

        Test.startTest();
        insert onboarding;
        onboarding.Customer_Name__c = 'Updated Customer';
        update onboarding;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :onboarding.Id]);
        onboarding = [SELECT Status__c, Kickoff_Task_Created__c FROM Onboarding__c WHERE Id = :onboarding.Id];
        System.assertEquals('Ready for Kickoff', onboarding.Status__c);
        System.assertEquals(true, onboarding.Kickoff_Task_Created__c);
    }

    @IsTest
    static void readinessReversalReturnsToNotReady() {
        User owner = implementationOwner();
        Onboarding__c onboarding = readyOnboarding(Date.today().addDays(10), owner.Id);
        insert onboarding;

        onboarding.Welcome_Email_Sent__c = false;
        update onboarding;

        onboarding = [SELECT Status__c FROM Onboarding__c WHERE Id = :onboarding.Id];
        System.assertEquals('Not Ready', onboarding.Status__c);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :onboarding.Id]);
    }

    @IsTest
    static void completedStatusIsNotChangedByReadinessFlow() {
        User owner = implementationOwner();
        Onboarding__c onboarding = readyOnboarding(Date.today().addDays(10), owner.Id);
        onboarding.Status__c = 'Kickoff Completed';

        insert onboarding;

        onboarding = [SELECT Status__c, Kickoff_Task_Created__c FROM Onboarding__c WHERE Id = :onboarding.Id];
        System.assertEquals('Kickoff Completed', onboarding.Status__c);
        System.assertEquals(true, onboarding.Kickoff_Task_Created__c);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :onboarding.Id]);
    }

    @IsTest
    static void dueDateFormulaCoversSundayMondayTuesdayAndNormalWeekday() {
        User owner = implementationOwner();
        List<Date> kickoffs = new List<Date>{
            Date.newInstance(2026, 8, 30), // Sunday
            Date.newInstance(2026, 8, 31), // Monday
            Date.newInstance(2026, 9, 1),  // Tuesday
            Date.newInstance(2026, 9, 2)   // Wednesday
        };
        List<Onboarding__c> records = new List<Onboarding__c>();
        for (Integer i = 0; i < kickoffs.size(); i++) {
            records.add(readyOnboarding(kickoffs[i], owner.Id));
            records[i].Customer_Name__c = 'Boundary ' + i;
        }

        Test.startTest();
        insert records;
        Test.stopTest();

        Map<Id, Date> expected = new Map<Id, Date>();
        expected.put(records[0].Id, kickoffs[0].addDays(-3));
        expected.put(records[1].Id, kickoffs[1].addDays(-4));
        expected.put(records[2].Id, kickoffs[2].addDays(-4));
        expected.put(records[3].Id, kickoffs[3].addDays(-2));

        for (Task task : [SELECT WhatId, ActivityDate FROM Task WHERE WhatId IN :expected.keySet()]) {
            System.assertEquals(expected.get(task.WhatId), task.ActivityDate);
        }
    }

    @IsTest
    static void bulkReadyAndNotReadyRecordsRemainIndependent() {
        User owner = implementationOwner();
        List<Onboarding__c> records = new List<Onboarding__c>();
        for (Integer i = 0; i < 10; i++) {
            Onboarding__c onboarding = readyOnboarding(Date.today().addDays(10 + i), owner.Id);
            onboarding.Customer_Name__c = 'Bulk ' + i;
            if (Math.mod(i, 2) == 0) {
                onboarding.Initial_Data_Received__c = false;
            }
            records.add(onboarding);
        }

        Test.startTest();
        insert records;
        Test.stopTest();

        Set<Id> readyIds = new Set<Id>();
        Set<Id> notReadyIds = new Set<Id>();
        for (Onboarding__c actual : [SELECT Id, Status__c FROM Onboarding__c WHERE Id IN :new Map<Id, Onboarding__c>(records).keySet()]) {
            if (actual.Status__c == 'Ready for Kickoff') {
                readyIds.add(actual.Id);
            } else {
                notReadyIds.add(actual.Id);
            }
        }
        System.assertEquals(5, readyIds.size());
        System.assertEquals(5, notReadyIds.size());
        System.assertEquals(5, [SELECT COUNT() FROM Task WHERE WhatId IN :readyIds]);
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId IN :notReadyIds]);
    }

    @IsTest
    static void reminderEligibilityDataBoundariesAreRepresented() {
        User owner = implementationOwner();
        List<Onboarding__c> records = new List<Onboarding__c>{
            new Onboarding__c(Customer_Name__c='Today', Status__c='Not Ready', Kickoff_Date__c=Date.today(), Implementation_Owner__c=owner.Id),
            new Onboarding__c(Customer_Name__c='Seven Days', Status__c='Not Ready', Kickoff_Date__c=Date.today().addDays(7), Implementation_Owner__c=owner.Id),
            new Onboarding__c(Customer_Name__c='Eight Days', Status__c='Not Ready', Kickoff_Date__c=Date.today().addDays(8), Implementation_Owner__c=owner.Id),
            new Onboarding__c(Customer_Name__c='Completed', Status__c='Kickoff Completed', Kickoff_Date__c=Date.today().addDays(3), Implementation_Owner__c=owner.Id),
            new Onboarding__c(Customer_Name__c='No Owner', Status__c='Not Ready', Kickoff_Date__c=Date.today().addDays(3)),
            new Onboarding__c(Customer_Name__c='No Date', Status__c='Not Ready', Implementation_Owner__c=owner.Id)
        };
        insert records;

        for (Onboarding__c actual : [SELECT Id, Status__c, Kickoff_Date__c, Implementation_Owner__c FROM Onboarding__c WHERE Id IN :new Map<Id, Onboarding__c>(records).keySet()]) {
            System.assertNotEquals(null, actual.Id);
        }
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId IN :new Map<Id, Onboarding__c>(records).keySet()]);
    }
}
