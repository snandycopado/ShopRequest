@IsTest
private class QuestionnaireDataControllerTest {

    private static Case createAuthorizedCase(String sessionToken) {
        Case c = new Case(
            Status = 'Send Questionary',
            Case_Type__c = 'New Branded Shop',
            SuppliedEmail = 'requester@example.com',
            Questionnaire_Token__c = OtpUtil.generateToken(),
            Questionnaire_Session_Token__c = sessionToken
        );
        insert c;
        return c;
    }

    private static void createQuestions() {
        insert new List<QuestionMaster__c>{
            new QuestionMaster__c(
                QuestionText__c = 'What is the proposed shop name?',
                Type__c = 'New Branded Shop',
                AnswerType__c = 'Text',
                IsRequired__c = true,
                Active__c = true
            ),
            new QuestionMaster__c(
                QuestionText__c = 'Preferred opening date?',
                Type__c = 'New Branded Shop',
                AnswerType__c = 'Date',
                IsRequired__c = false,
                Active__c = true
            ),
            new QuestionMaster__c(
                QuestionText__c = 'Store size category?',
                Type__c = 'New Branded Shop',
                AnswerType__c = 'Option',
                Options__c = 'Small,Medium,Large',
                IsRequired__c = false,
                Active__c = true
            ),
            new QuestionMaster__c(
                QuestionText__c = 'Inactive question should not appear',
                Type__c = 'New Branded Shop',
                AnswerType__c = 'Text',
                IsRequired__c = false,
                Active__c = false
            ),
            new QuestionMaster__c(
                QuestionText__c = 'Question for a different Case Type',
                Type__c = 'New Franchise Shop',
                AnswerType__c = 'Text',
                IsRequired__c = false,
                Active__c = true
            )
        };
    }

    @IsTest
    static void getQuestionnaireReturnsOnlyActiveMatchingQuestions() {
        createQuestions();
        String sessionToken = OtpUtil.generateToken();
        Case c = createAuthorizedCase(sessionToken);

        Test.startTest();
        QuestionnaireDataController.QuestionnaireWrapper result =
            QuestionnaireDataController.getQuestionnaire(c.Questionnaire_Token__c, sessionToken);
        Test.stopTest();

        System.assertEquals(false, result.isReadOnly, 'No answers exist yet');
        System.assertEquals(3, result.questions.size(), 'Only the 3 active New Branded Shop questions should be returned');
    }

    @IsTest
    static void unauthorizedSessionTokenThrows() {
        createQuestions();
        Case c = createAuthorizedCase(OtpUtil.generateToken());

        Boolean threw = false;
        try {
            QuestionnaireDataController.getQuestionnaire(c.Questionnaire_Token__c, 'wrong-session-token');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'A mismatched session token must be rejected');
    }

    @IsTest
    static void submitAnswersCreatesRecordsAndUpdatesStatus() {
        createQuestions();
        String sessionToken = OtpUtil.generateToken();
        Case c = createAuthorizedCase(sessionToken);

        List<QuestionMaster__c> masters = [
            SELECT Id FROM QuestionMaster__c WHERE Type__c = 'New Branded Shop' AND Active__c = true
        ];

        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        for (QuestionMaster__c m : masters) {
            payload.add(new Map<String, Object>{ 'questionMasterId' => m.Id, 'answerValue' => 'Sample Answer' });
        }

        Test.startTest();
        QuestionnaireDataController.submitAnswers(c.Questionnaire_Token__c, sessionToken, JSON.serialize(payload));
        Test.stopTest();

        Case result = [SELECT Status, Questionnaire_Session_Token__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('Answer Received', result.Status, 'Status should move to Answer Received');
        System.assertEquals(null, result.Questionnaire_Session_Token__c, 'Session token should be cleared after submit');

        List<QuestionAnswer__c> answers = [SELECT Id FROM QuestionAnswer__c WHERE Case__c = :c.Id];
        System.assertEquals(masters.size(), answers.size(), 'One answer per active matching question should be created');
    }

    @IsTest
    static void submitAnswersMissingRequiredFieldThrows() {
        createQuestions();
        String sessionToken = OtpUtil.generateToken();
        Case c = createAuthorizedCase(sessionToken);

        Boolean threw = false;
        try {
            QuestionnaireDataController.submitAnswers(c.Questionnaire_Token__c, sessionToken, JSON.serialize(new List<Object>()));
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Omitting a required answer must be rejected server-side');
    }

    @IsTest
    static void submitAnswersTwiceIsRejected() {
        createQuestions();
        String sessionToken = OtpUtil.generateToken();
        Case c = createAuthorizedCase(sessionToken);

        List<QuestionMaster__c> masters = [
            SELECT Id FROM QuestionMaster__c WHERE Type__c = 'New Branded Shop' AND Active__c = true
        ];
        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        for (QuestionMaster__c m : masters) {
            payload.add(new Map<String, Object>{ 'questionMasterId' => m.Id, 'answerValue' => 'Sample Answer' });
        }
        QuestionnaireDataController.submitAnswers(c.Questionnaire_Token__c, sessionToken, JSON.serialize(payload));

        String secondSessionToken = OtpUtil.generateToken();
        c.Questionnaire_Session_Token__c = secondSessionToken;
        update c;

        Boolean threw = false;
        try {
            QuestionnaireDataController.submitAnswers(c.Questionnaire_Token__c, secondSessionToken, JSON.serialize(payload));
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'A second submission for the same Case must be rejected');
    }

    @IsTest
    static void getQuestionnaireIsReadOnlyAfterSubmission() {
        createQuestions();
        String sessionToken = OtpUtil.generateToken();
        Case c = createAuthorizedCase(sessionToken);

        List<QuestionMaster__c> masters = [
            SELECT Id FROM QuestionMaster__c WHERE Type__c = 'New Branded Shop' AND Active__c = true
        ];
        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        for (QuestionMaster__c m : masters) {
            payload.add(new Map<String, Object>{ 'questionMasterId' => m.Id, 'answerValue' => 'Sample Answer' });
        }
        QuestionnaireDataController.submitAnswers(c.Questionnaire_Token__c, sessionToken, JSON.serialize(payload));

        String newSessionToken = OtpUtil.generateToken();
        c.Questionnaire_Session_Token__c = newSessionToken;
        update c;

        Test.startTest();
        QuestionnaireDataController.QuestionnaireWrapper result =
            QuestionnaireDataController.getQuestionnaire(c.Questionnaire_Token__c, newSessionToken);
        Test.stopTest();

        System.assertEquals(true, result.isReadOnly, 'Form should be read-only once answers exist');
        for (QuestionnaireDataController.QuestionWrapper w : result.questions) {
            System.assertEquals('Sample Answer', w.existingAnswer, 'Previously submitted answers should be pre-filled');
        }
    }
}
