/**
 * Guest-callable OTP gate for the public questionnaire page. This is the ONLY
 * Apex surface (along with QuestionnaireDataController) exposed to the Site
 * Guest User - the Guest profile is granted no direct object permissions on
 * Case/QuestionMaster__c/QuestionAnswer__c, so this narrow, validated surface
 * is the sole way in. "without sharing" is required because a guest user has
 * no row-level access to the Case being looked up; every method still
 * resolves the Case strictly by the opaque Questionnaire_Token__c (never a
 * record Id) and never reveals whether a given token exists.
 */
public without sharing class QuestionnaireAuthController {

    private static final Integer MAX_ATTEMPTS = 5;
    private static final Integer OTP_LENGTH = 6;
    private static final String GENERIC_ERROR = 'We could not process your request. Please use the link from your email again.';
    private static final String INVALID_CODE_ERROR = 'Invalid or expired code. Please request a new one.';

    @AuraEnabled
    public static void requestOtp(String token) {
        Case c = getCaseByToken(token);

        String otp = OtpUtil.generateNumericOtp(OTP_LENGTH);
        String salt = OtpUtil.generateSalt();

        c.Questionnaire_OTP_Hash__c = OtpUtil.hash(otp + salt);
        c.Questionnaire_OTP_Salt__c = salt;
        c.Questionnaire_Session_Token__c = null;
        c.OTP_Attempt_Count__c = 0;
        c.Questionnaire_Locked__c = false;
        update c;

        QuestionnaireEmailService.sendOtpEmail(c, otp);
    }

    @AuraEnabled
    public static String verifyOtp(String token, String otp) {
        Case c = getCaseByToken(token);

        if (c.Questionnaire_Locked__c) {
            throw new AuraHandledException('Too many incorrect attempts. Please request a new code.');
        }
        if (String.isBlank(c.Questionnaire_OTP_Hash__c) || String.isBlank(otp)) {
            throw new AuraHandledException(INVALID_CODE_ERROR);
        }

        String candidateHash = OtpUtil.hash(otp + c.Questionnaire_OTP_Salt__c);
        if (!candidateHash.equals(c.Questionnaire_OTP_Hash__c)) {
            Integer attempts = (Integer) (c.OTP_Attempt_Count__c == null ? 0 : c.OTP_Attempt_Count__c) + 1;
            c.OTP_Attempt_Count__c = attempts;
            if (attempts >= MAX_ATTEMPTS) {
                c.Questionnaire_Locked__c = true;
            }
            update c;
            throw new AuraHandledException(INVALID_CODE_ERROR);
        }

        String sessionToken = OtpUtil.generateToken();
        c.Questionnaire_Session_Token__c = sessionToken;
        c.Questionnaire_OTP_Hash__c = null;
        c.Questionnaire_OTP_Salt__c = null;
        c.OTP_Attempt_Count__c = 0;
        update c;

        return sessionToken;
    }

    private static Case getCaseByToken(String token) {
        if (String.isBlank(token)) {
            throw new AuraHandledException(GENERIC_ERROR);
        }
        List<Case> cases = [
            SELECT Id, SuppliedEmail, ContactId, Contact.Email,
                   Questionnaire_OTP_Hash__c, Questionnaire_OTP_Salt__c,
                   Questionnaire_Session_Token__c, OTP_Attempt_Count__c, Questionnaire_Locked__c
            FROM Case
            WHERE Questionnaire_Token__c = :token
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException(GENERIC_ERROR);
        }
        return cases[0];
    }
}
