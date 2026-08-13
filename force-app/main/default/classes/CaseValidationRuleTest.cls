@IsTest
private class caseValidationRuleTest {

    @IsTest
    static void BlocksSendQuestionaryWithoutCaseTypeOnShopRequestRecordType@1234() {
        Id shopRequestRecordTypeId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'Shop_Request' LIMIT 1
        ].Id;

        Case c = new Case(RecordTypeId = shopRequestRecordTypeId, Status = 'Initial Request');
        insert c;

        c.Status = 'Send Questionary';
        Boolean threw = false;
        try {
            update c;
        } catch (DmlException e) {
            threw = true;
            System.assert(e.getMessage().contains('Case Type is required'), 'Should surface the validation rule message');
        }
        System.assert(threw, 'Moving to Send Questionary without a Case Type must be blocked');
    }

    @IsTest
    static void allowsSendQuestionaryWhenCaseTypeIsSet() {
        Id shopRequestRecordTypeId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'Shop_Request' LIMIT 1
        ].Id;

        Case c = new Case(
            RecordTypeId = shopRequestRecordTypeId,
            Status = 'Initial Request',
            Case_Type__c = 'New Franchise Shop'
        );
        insert c;

        c.Status = 'Send Questionary';
        update c;

        Case result = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assertEquals('Send Questionary', result.Status);
    }
}
