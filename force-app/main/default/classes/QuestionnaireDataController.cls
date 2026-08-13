/**
 * Guest-callable questionnaire data access, gated by the session token that
 * QuestionnaireAuthController.verifyOtp issues. Neither method here can be
 * reached without first passing OTP - getAuthorizedCase re-validates the
 * session token against the Case on every call.
 */
public without sharing class QuestionnaireDataController {

    private static final String SESSION_ERROR = 'Your session has expired. Please verify with the code from your email again.';

    public class QuestionWrapper {
        @AuraEnabled public Id questionMasterId;
        @AuraEnabled public String questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public String answerType;
        @AuraEnabled public String options;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public String existingAnswer;
    }

    public class QuestionnaireWrapper {
        @AuraEnabled public Boolean isReadOnly;
        @AuraEnabled public List<QuestionWrapper> questions;
    }

    public class AnswerInput {
        @AuraEnabled public Id questionMasterId;
        @AuraEnabled public String answerValue;
    }

    @AuraEnabled
    public static QuestionnaireWrapper getQuestionnaire(String token, String sessionToken) {
        Case c = getAuthorizedCase(token, sessionToken);

        Map<Id, QuestionAnswer__c> existingByQuestion = new Map<Id, QuestionAnswer__c>();
        for (QuestionAnswer__c qa : [
            SELECT QuestionMaster__c, Answer_Value__c
            FROM QuestionAnswer__c
            WHERE Case__c = :c.Id
        ]) {
            existingByQuestion.put(qa.QuestionMaster__c, qa);
        }

        List<QuestionMaster__c> masters = [
            SELECT Id, QuestionId__c, QuestionText__c, AnswerType__c, Options__c, IsRequired__c
            FROM QuestionMaster__c
            WHERE Type__c = :c.Case_Type__c AND Active__c = true
            ORDER BY CreatedDate ASC
        ];

        List<QuestionWrapper> wrappers = new List<QuestionWrapper>();
        for (QuestionMaster__c m : masters) {
            QuestionWrapper w = new QuestionWrapper();
            w.questionMasterId = m.Id;
            w.questionId = m.QuestionId__c;
            w.questionText = m.QuestionText__c;
            w.answerType = m.AnswerType__c;
            w.options = m.Options__c;
            w.isRequired = m.IsRequired__c;
            if (existingByQuestion.containsKey(m.Id)) {
                w.existingAnswer = existingByQuestion.get(m.Id).Answer_Value__c;
            }
            wrappers.add(w);
        }

        QuestionnaireWrapper result = new QuestionnaireWrapper();
        result.isReadOnly = !existingByQuestion.isEmpty();
        result.questions = wrappers;
        return result;
    }

    @AuraEnabled
    public static void submitAnswers(String token, String sessionToken, String answersJson) {
        Case c = getAuthorizedCase(token, sessionToken);

        Integer existingCount = [SELECT COUNT() FROM QuestionAnswer__c WHERE Case__c = :c.Id];
        if (existingCount > 0) {
            throw new AuraHandledException('This questionnaire has already been submitted.');
        }

        List<AnswerInput> answers = String.isBlank(answersJson)
            ? new List<AnswerInput>()
            : (List<AnswerInput>) JSON.deserialize(answersJson, List<AnswerInput>.class);
        Map<Id, AnswerInput> answerByQuestionId = new Map<Id, AnswerInput>();
        for (AnswerInput a : answers) {
            answerByQuestionId.put(a.questionMasterId, a);
        }

        List<QuestionMaster__c> masters = [
            SELECT Id, QuestionId__c, QuestionText__c, IsRequired__c
            FROM QuestionMaster__c
            WHERE Type__c = :c.Case_Type__c AND Active__c = true
        ];

        List<QuestionAnswer__c> toInsert = new List<QuestionAnswer__c>();
        for (QuestionMaster__c m : masters) {
            AnswerInput a = answerByQuestionId.get(m.Id);
            String value = a == null ? null : a.answerValue;
            if (m.IsRequired__c && String.isBlank(value)) {
                throw new AuraHandledException('Please answer all required questions.');
            }
            if (String.isBlank(value)) {
                continue;
            }
            QuestionAnswer__c qa = new QuestionAnswer__c();
            qa.Case__c = c.Id;
            qa.QuestionMaster__c = m.Id;
            qa.Question_Id__c = m.QuestionId__c;
            qa.Question_Text__c = m.QuestionText__c;
            qa.Answer_Value__c = value;
            toInsert.add(qa);
        }

        insert toInsert;

        c.Status = 'Answer Received';
        c.Questionnaire_Session_Token__c = null;
        update c;
    }

    private static Case getAuthorizedCase(String token, String sessionToken) {
        if (String.isBlank(token) || String.isBlank(sessionToken)) {
            throw new AuraHandledException(SESSION_ERROR);
        }
        List<Case> cases = [
            SELECT Id, Case_Type__c, Status, Questionnaire_Session_Token__c
            FROM Case
            WHERE Questionnaire_Token__c = :token
            LIMIT 1
        ];
        if (cases.isEmpty() || !sessionToken.equals(cases[0].Questionnaire_Session_Token__c)) {
            throw new AuraHandledException(SESSION_ERROR);
        }
        return cases[0];
    }
}
