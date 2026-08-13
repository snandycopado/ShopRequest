@IsTest
private class QuestionnaireAuthControllerTest {

    private static Case createCaseWithToken() {
        Case c = new Case(
            Status = 'Send Questionary',
            Case_Type__c = 'New Branded Shop',
            SuppliedEmail = 'requester@example.com',
            Questionnaire_Token__c = OtpUtil.generateToken()
        );
        insert c;
        return c;
    }

    @IsTest
    static void requestOtpInvalidTokenThrowsGenericError() {
        Boolean threw = false;
        try {
            QuestionnaireAuthController.requestOtp('does-not-exist');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'An invalid token should throw a generic AuraHandledException');
    }

    @IsTest
    static void requestOtpStoresHashAndSendsEmail() {
        Case c = createCaseWithToken();

        Test.startTest();
        QuestionnaireAuthController.requestOtp(c.Questionnaire_Token__c);
        Test.stopTest();

        Case result = [SELECT Questionnaire_OTP_Hash__c, Questionnaire_OTP_Salt__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, result.Questionnaire_OTP_Hash__c, 'An OTP hash should be stored');
        System.assertNotEquals(null, result.Questionnaire_OTP_Salt__c, 'A salt should be stored');
        System.assertEquals(1, Limits.getEmailInvocations(), 'Exactly one OTP email should have been sent');
    }

    @IsTest
    static void verifyOtpSucceedsWithCorrectCodeAndIssuesSessionToken() {
        Case c = createCaseWithToken();
        String knownOtp = '123456';
        String salt = OtpUtil.generateSalt();
        c.Questionnaire_OTP_Hash__c = OtpUtil.hash(knownOtp + salt);
        c.Questionnaire_OTP_Salt__c = salt;
        update c;

        Test.startTest();
        String sessionToken = QuestionnaireAuthController.verifyOtp(c.Questionnaire_Token__c, knownOtp);
        Test.stopTest();

        System.assertNotEquals(null, sessionToken, 'A session token should be issued on success');

        Case result = [SELECT Questionnaire_OTP_Hash__c, Questionnaire_Session_Token__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(sessionToken, result.Questionnaire_Session_Token__c, 'Case should be updated with the session token');
        System.assertEquals(null, result.Questionnaire_OTP_Hash__c, 'OTP hash should be cleared after successful use (single-use)');
    }

    @IsTest
    static void verifyOtpFailsWithWrongCodeAndLocksAfterMaxAttempts() {
        Case c = createCaseWithToken();
        String knownOtp = '123456';
        String salt = OtpUtil.generateSalt();
        c.Questionnaire_OTP_Hash__c = OtpUtil.hash(knownOtp + salt);
        c.Questionnaire_OTP_Salt__c = salt;
        update c;

        Test.startTest();
        for (Integer i = 0; i < 5; i++) {
            Boolean threw = false;
            try {
                QuestionnaireAuthController.verifyOtp(c.Questionnaire_Token__c, '000000');
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assert(threw, 'A wrong code should always throw');
        }
        Test.stopTest();

        Case result = [SELECT Questionnaire_Locked__c, OTP_Attempt_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, result.Questionnaire_Locked__c, 'Case should be locked after 5 failed attempts');
    }

    @IsTest
    static void resendInvalidatesThePreviousOtp() {
        Case c = createCaseWithToken();
        String knownOtp = '123456';
        String salt = OtpUtil.generateSalt();
        c.Questionnaire_OTP_Hash__c = OtpUtil.hash(knownOtp + salt);
        c.Questionnaire_OTP_Salt__c = salt;
        update c;

        Test.startTest();
        QuestionnaireAuthController.requestOtp(c.Questionnaire_Token__c);
        Boolean threw = false;
        try {
            QuestionnaireAuthController.verifyOtp(c.Questionnaire_Token__c, knownOtp);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'The previous OTP must no longer be valid after a resend');
    }
}
