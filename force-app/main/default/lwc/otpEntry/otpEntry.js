import { LightningElement, api } from 'lwc';
import requestOtp from '@salesforce/apex/QuestionnaireAuthController.requestOtp';
import verifyOtp from '@salesforce/apex/QuestionnaireAuthController.verifyOtp';

const LOCKOUT_PHRASE = 'too many incorrect attempts';

export default class OtpEntry extends LightningElement {
    @api token;

    otpValue = '';
    isVerifying = false;
    isResending = false;
    isLocked = false;
    errorMessage;
    resendMessage;

    handleOtpChange(event) {
        const digitsOnly = event.target.value.replace(/\D/g, '').slice(0, 6);
        event.target.value = digitsOnly;
        this.otpValue = digitsOnly;
        this.errorMessage = undefined;
    }

    get isVerifyDisabled() {
        return this.isVerifying || this.isLocked || this.otpValue.length !== 6;
    }

    get isBusy() {
        return this.isVerifying || this.isResending;
    }

    async handleVerify() {
        this.isVerifying = true;
        this.errorMessage = undefined;
        try {
            const sessionToken = await verifyOtp({ token: this.token, otp: this.otpValue });
            this.dispatchEvent(new CustomEvent('verified', { detail: { sessionToken } }));
        } catch (error) {
            this.errorMessage = this.extractError(error);
            this.isLocked = this.errorMessage.toLowerCase().includes(LOCKOUT_PHRASE);
        } finally {
            this.isVerifying = false;
        }
    }

    async handleResend() {
        this.isResending = true;
        this.errorMessage = undefined;
        this.resendMessage = undefined;
        this.otpValue = '';
        try {
            await requestOtp({ token: this.token });
            this.isLocked = false;
            this.resendMessage = 'A new code has been sent to your email.';
        } catch (error) {
            this.errorMessage = this.extractError(error);
        } finally {
            this.isResending = false;
        }
    }

    extractError(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : 'Something went wrong. Please try again.';
    }
}
