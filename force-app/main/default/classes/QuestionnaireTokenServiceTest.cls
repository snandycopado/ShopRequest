@IsTest
private class QuestionnaireTokenServiceTest {

    @IsTest
    static void generatesTokenWhenBlank() {
        Case c = new Case(Status = 'Initial Request', Case_Type__c = 'New Branded Shop');
        insert c;

        Test.startTest();
        QuestionnaireTokenService.ensureToken(new List<Id>{ c.Id });
        Test.stopTest();

        Case result = [SELECT Questionnaire_Token__c, OTP_Attempt_Count__c, Questionnaire_Locked__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, result.Questionnaire_Token__c, 'A token should have been generated');
        System.assertEquals(0, (Integer) result.OTP_Attempt_Count__c, 'Attempt count should be reset');
        System.assertEquals(false, result.Questionnaire_Locked__c, 'Lock should be reset');
    }

    @IsTest
    static void doesNotRegenerateExistingToken() {
        Case c = new Case(
            Status = 'Initial Request',
            Case_Type__c = 'New Branded Shop',
            Questionnaire_Token__c = OtpUtil.generateToken()
        );
        insert c;
        String originalToken = c.Questionnaire_Token__c;

        Test.startTest();
        QuestionnaireTokenService.ensureToken(new List<Id>{ c.Id });
        Test.stopTest();

        Case result = [SELECT Questionnaire_Token__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(originalToken, result.Questionnaire_Token__c, 'An existing token should never be replaced');
    }
}
