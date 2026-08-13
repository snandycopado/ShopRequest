# Shop Request Management — Salesforce DX project

Code review and general guidance for Claude when working in this repo (including automated PR reviews via GitHub Actions).

## Apex conventions

- A top-level Apex class name must exactly match its file name (case-sensitive) — a mismatch breaks deployment. Always flag this.
- Apex identifiers cannot contain special characters like `@`. Flag any occurrence.
- Avoid SOQL or DML statements inside loops — flag as a bulkification/governor-limit issue.
- Test classes and test methods should use lowerCamelCase for methods; classes use UpperCamelCase.
- Prefer `with sharing` on classes that touch user-visible data unless there's a documented reason for `without sharing`.
- Every new/changed public method on a class with existing `@IsTest` coverage should have a corresponding test case added or updated.

## LWC conventions

- Flag missing `js-meta.xml` target configuration when a new LWC component is added.
- Flag accessibility issues: missing `aria-label`/`alt` text, non-semantic clickable `div`s without keyboard handling.

## Project context

- This project manages "Shop Request" Cases with a guided questionnaire flow (OTP-verified public/guest access via `OtpUtil`, `QuestionnaireAuthController`, `QuestionnaireTokenService`).
- `Case_Type__c` must be set before a Case can move to the `Send Questionary` status — enforced by a validation rule (`Case_Type_Required_Before_Questionary`). Changes touching Case status transitions should consider this rule.
