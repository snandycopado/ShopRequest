/**
 * Invocable action called from the Case_Send_Questionnaire_Email flow when a
 * Case's Status becomes "Send Questionary". Generates the obfuscated
 * questionnaire link token (idempotent - never regenerates an existing one)
 * and resets any prior OTP/session state so a case that re-enters this
 * status starts clean.
 */
public with sharing class QuestionnaireTokenService {

    @InvocableMethod(
        label='Ensure Questionnaire Token'
        description='Generates a secure questionnaire token for each Case that does not already have one, and resets OTP state.'
    )
    public static void ensureToken(List<Id> caseIds) {
        List<Case> cases = [
            SELECT Id, Questionnaire_Token__c
            FROM Case
            WHERE Id IN :caseIds
        ];

        for (Case c : cases) {
            if (String.isBlank(c.Questionnaire_Token__c)) {
                c.Questionnaire_Token__c = OtpUtil.generateToken();
            }
            c.Questionnaire_OTP_Hash__c = null;
            c.Questionnaire_OTP_Salt__c = null;
            c.Questionnaire_Session_Token__c = null;
            c.OTP_Attempt_Count__c = 0;
            c.Questionnaire_Locked__c = false;
        }

        if (!cases.isEmpty()) {
            update cases;
        }
    }
}
