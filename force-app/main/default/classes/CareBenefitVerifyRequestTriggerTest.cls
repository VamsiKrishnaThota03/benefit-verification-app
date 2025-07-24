@isTest
private class CareBenefitVerifyRequestTriggerTest {
    @isTest
    static void testQueueAssignmentAndCallout() {
        // Create queues
        Group consultationQueue = new Group(Name = 'Consultation Care Queue', DeveloperName = 'Consultation_Care_Queue', Type = 'Queue');
        Group infusionQueue = new Group(Name = 'Infusion Care Queue', DeveloperName = 'Infusion_Care_Queue', Type = 'Queue');
        Group surgeryQueue = new Group(Name = 'Surgery Care Queue', DeveloperName = 'Surgery_Care_Queue', Type = 'Queue');
        insert new List<Group>{consultationQueue, infusionQueue, surgeryQueue};

        // Create Patient Account
        Account patient = new Account(Name = 'Test Patient');
        insert patient;
        // Create Member Plan
        MemberPlan__c plan = new MemberPlan__c(Name = 'Test Plan', GroupNumber__c = 'G1', PolicyNumber__c = 'P1', SubscriberId__c = 'S1', Member__c = patient.Id, Payer__c = patient.Id, Subscriber__c = patient.Id, MemberNumber__c = 'M1', EffectiveFrom__c = Date.today(), EffectiveTo__c = Date.today().addYears(1));
        insert plan;

        // Create request with each Service Type
        List<CareBenefitVerifyRequest__c> requests = new List<CareBenefitVerifyRequest__c>{
            new CareBenefitVerifyRequest__c(Patient__c = patient.Id, MemberPlan__c = plan.Id, ServiceType__c = 'Consultation', ServiceDate__c = Date.today(), Status__c = 'Submitted'),
            new CareBenefitVerifyRequest__c(Patient__c = patient.Id, MemberPlan__c = plan.Id, ServiceType__c = 'Infusion', ServiceDate__c = Date.today(), Status__c = 'Submitted'),
            new CareBenefitVerifyRequest__c(Patient__c = patient.Id, MemberPlan__c = plan.Id, ServiceType__c = 'Surgery', ServiceDate__c = Date.today(), Status__c = 'Submitted')
        };
        insert requests;

        // Verify Owner assignment
        requests = [SELECT Id, ServiceType__c, OwnerId FROM CareBenefitVerifyRequest__c];
        for (CareBenefitVerifyRequest__c req : requests) {
            if (req.ServiceType__c == 'Consultation') {
                System.assertEquals(consultationQueue.Id, req.OwnerId, 'Consultation should be assigned to Consultation_Care_Queue');
            } else if (req.ServiceType__c == 'Infusion') {
                System.assertEquals(infusionQueue.Id, req.OwnerId, 'Infusion should be assigned to Infusion_Care_Queue');
            } else if (req.ServiceType__c == 'Surgery') {
                System.assertEquals(surgeryQueue.Id, req.OwnerId, 'Surgery should be assigned to Surgery_Care_Queue');
            }
        }
    }
} 