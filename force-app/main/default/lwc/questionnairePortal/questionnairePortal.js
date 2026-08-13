import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import requestOtp from '@salesforce/apex/QuestionnaireAuthController.requestOtp';

const STATE = {
    LOADING: 'loading',
    OTP: 'otp',
    FORM: 'form',
    ERROR: 'error'
};

export default class QuestionnairePortal extends LightningElement {
    token;
    sessionToken;
    state = STATE.LOADING;
    errorMessage = 'This link is no longer valid. Please use the link from your most recent email.';

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        const incomingToken = pageRef && pageRef.state ? pageRef.state.token : undefined;

        if (incomingToken) {
            if (incomingToken !== this.token) {
                this.token = incomingToken;
                this.initiateOtp();
            }
        } else if (!this.token) {
            this.state = STATE.ERROR;
        }
    }

    async initiateOtp() {
        this.state = STATE.LOADING;
        try {
            await requestOtp({ token: this.token });
            this.state = STATE.OTP;
        } catch (error) {
            this.state = STATE.ERROR;
        }
    }

    handleVerified(event) {
        this.sessionToken = event.detail.sessionToken;
        this.state = STATE.FORM;
    }

    get isLoading() {
        return this.state === STATE.LOADING;
    }

    get isOtpStep() {
        return this.state === STATE.OTP;
    }

    get isFormStep() {
        return this.state === STATE.FORM;
    }

    get isError() {
        return this.state === STATE.ERROR;
    }
}
