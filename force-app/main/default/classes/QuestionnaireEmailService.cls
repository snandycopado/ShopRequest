/**
 * Sends the one-time-password email during the guest OTP flow. The initial
 * "your questionnaire is ready" email (containing the link) is intentionally
 * NOT sent from here - it is sent declaratively by the Case_Send_Questionnaire_Email
 * flow via a Lightning Email Template, so admins can edit that wording without
 * a code deployment. This class only ever needs to run in a guest context,
 * hence "without sharing".
 */
public without sharing class QuestionnaireEmailService {

    public static void sendOtpEmail(Case c, String otp) {
        String toAddress = resolveRecipient(c);
        if (String.isBlank(toAddress)) {
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress });
        mail.setSubject('Your Shop Request verification code');
        mail.setPlainTextBody(
            'Your one-time verification code is: ' + otp + '\n\n' +
            'Enter this code on the questionnaire page to continue.\n' +
            'If you request a new code, this code will stop working.'
        );
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    private static String resolveRecipient(Case c) {
        if (String.isNotBlank(c.SuppliedEmail)) {
            return c.SuppliedEmail;
        }
        if (c.ContactId != null && c.Contact != null && String.isNotBlank(c.Contact.Email)) {
            return c.Contact.Email;
        }
        return null;
    }
}
