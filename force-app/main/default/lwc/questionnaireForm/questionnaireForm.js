import { LightningElement, api } from 'lwc';
import getQuestionnaire from '@salesforce/apex/QuestionnaireDataController.getQuestionnaire';
import submitAnswers from '@salesforce/apex/QuestionnaireDataController.submitAnswers';

export default class QuestionnaireForm extends LightningElement {
    @api token;
    @api sessionToken;

    isLoading = true;
    isSubmitting = false;
    isReadOnly = false;
    isSubmitted = false;
    errorMessage;
    questions = [];

    connectedCallback() {
        this.loadQuestionnaire();
    }

    async loadQuestionnaire() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const result = await getQuestionnaire({ token: this.token, sessionToken: this.sessionToken });
            this.isReadOnly = result.isReadOnly;
            this.questions = result.questions.map((q) => this.toViewModel(q));
        } catch (error) {
            this.errorMessage = this.extractError(error);
        } finally {
            this.isLoading = false;
        }
    }

    toViewModel(q) {
        const isOption = q.answerType === 'Option';
        const isBoolean = q.answerType === 'Boolean';
        const isDate = q.answerType === 'Date';
        const isText = q.answerType === 'Text';
        return {
            questionMasterId: q.questionMasterId,
            questionId: q.questionId,
            questionText: q.questionText,
            isRequired: q.isRequired,
            isOption,
            isBoolean,
            isDate,
            isText,
            optionChoices: isOption && q.options
                ? q.options.split(',').map((o) => o.trim()).filter((o) => o)
                : [],
            value: this.initialValue(q, isBoolean)
        };
    }

    initialValue(q, isBoolean) {
        if (q.existingAnswer === undefined || q.existingAnswer === null) {
            return isBoolean ? false : '';
        }
        return isBoolean ? q.existingAnswer === 'true' : q.existingAnswer;
    }

    handleTextChange(event) {
        this.updateValue(event.target.dataset.id, event.target.value);
    }

    handleCheckboxChange(event) {
        this.updateValue(event.target.dataset.id, event.target.checked);
    }

    updateValue(questionMasterId, value) {
        this.questions = this.questions.map((q) =>
            q.questionMasterId === questionMasterId ? { ...q, value } : q
        );
    }

    get hasMissingRequired() {
        return this.questions.some((q) => q.isRequired && this.isBlank(q.value, q.isBoolean));
    }

    isBlank(value, isBoolean) {
        if (isBoolean) {
            return false;
        }
        return value === undefined || value === null || String(value).trim() === '';
    }

    async handleSubmit() {
        if (this.hasMissingRequired) {
            this.errorMessage = 'Please answer all required questions before submitting.';
            return;
        }
        this.isSubmitting = true;
        this.errorMessage = undefined;
        try {
            const payload = this.questions
                .filter((q) => !this.isBlank(q.value, q.isBoolean))
                .map((q) => ({
                    questionMasterId: q.questionMasterId,
                    answerValue: q.isBoolean ? String(q.value) : q.value
                }));
            await submitAnswers({
                token: this.token,
                sessionToken: this.sessionToken,
                answersJson: JSON.stringify(payload)
            });
            this.isSubmitted = true;
            this.isReadOnly = true;
        } catch (error) {
            this.errorMessage = this.extractError(error);
        } finally {
            this.isSubmitting = false;
        }
    }

    extractError(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : 'Something went wrong. Please try again.';
    }
}
