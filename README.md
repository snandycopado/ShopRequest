# Shop Request Management

Salesforce DX project implementing Phase 1 of the shop request questionnaire process:
**Email-to-Case → Agent triage (Case Path) → public OTP-gated questionnaire → Answer Received.**

This README covers what's deployable, what still requires manual Setup clicks, and how to test
it end-to-end.

## What's in this repo

| Area | Metadata |
|---|---|
| Data model | `objects/QuestionMaster__c`, `objects/QuestionAnswer__c`, Case field additions, `Shop_Request_Settings__mdt` |
| Process control | `objects/Case/businessProcesses`, `objects/Case/recordTypes/Shop_Request`, `objects/Case/validationRules`, `pathAssistants/Case_Shop_Request_Path` |
| Automation | `flows/Case_Send_Questionnaire_Email` (Record-Triggered Flow), `workflows/Case.workflow-meta.xml` (Email Alert), `email/Shop_Request_Email_Templates` (Lightning/HTML email template) |
| Apex | `classes/OtpUtil`, `QuestionnaireTokenService`, `QuestionnaireEmailService`, `QuestionnaireAuthController`, `QuestionnaireDataController` + test classes |
| Guest access | `permissionsets/Shop_Request_Guest_Access` (Apex Class access only - **no** object permissions) |
| UI | `lwc/questionnairePortal` (page component), `lwc/otpEntry`, `lwc/questionnaireForm` |

## Deploy the metadata

```
sf org login web -a your-org-alias
sf project deploy start -o your-org-alias
sf apex run test -o your-org-alias -l RunLocalTests -r human
```

## Manual Setup steps (cannot be captured as metadata)

Do these **after** deploying:

1. **Email-to-Case**: Setup → Email-to-Case → enable it, create a routing address, and set its
   default Case Record Type to **Shop Request** and default Status to **Initial Request**.
2. **Digital Experiences**: enable Digital Experiences (Setup → Digital Experiences → Settings),
   then create a new site (recommended template: **LWR "Build Your Own"** for the cleanest CSS
   control and best mobile performance). Activate it and note its domain.
3. In **Experience Builder**, create a new page (e.g. `/questionnaire`) and drag the
   **Shop Request Questionnaire Portal** (`c-questionnaire-portal`) component onto it. Make the
   page public (no login required) and turn off search-engine indexing for it.
4. Assign the **Shop Request Guest Access** permission set to the site's **Guest User**:
   Setup → Digital Experiences → \[your site\] → Administration → Pages → find the Guest User
   Profile → assign the permission set (or add the two Apex classes to the guest profile directly
   if your org manages guest access that way).
5. Update the `Shop_Request_Settings__mdt` **Default** record's `Site_Base_URL__c` with the real
   site URL plus your questionnaire page path, e.g.
   `https://yourdomain.my.site.com/shopportal/questionnaire`. The `Case.Questionnaire_Link__c`
   formula field reads this value, so the emailed link won't be correct until this is set.
6. Optional: after building the page once in Experience Builder, `sf project retrieve start` to
   pull the resulting `ExperienceBundle` metadata into this repo so future deployments don't
   require rebuilding the page by hand.
7. Optional: assign a Page Layout for the **Shop Request** Case record type per profile if you
   want a tailored agent-facing layout (otherwise it inherits the org's default Case layout).

## How the link/OTP security model works

- The emailed link never contains the Case Id - it carries `Case.Questionnaire_Token__c`, a
  32-byte random value generated once by `QuestionnaireTokenService` when the Case enters
  **Send Questionary**.
- Opening the link triggers `QuestionnaireAuthController.requestOtp`, which emails a fresh 6-digit
  OTP every time (no time-based expiry, but each new OTP invalidates the previous one - the old
  hash is overwritten).
- A correct `verifyOtp` call issues a random session token (`Questionnaire_Session_Token__c`),
  which `QuestionnaireDataController` requires on every subsequent call. This session token is
  never persisted client-side beyond the page session, so refreshing the page always re-demands
  OTP verification.
- The Guest User profile has **zero object permissions** on `Case`, `QuestionMaster__c`, or
  `QuestionAnswer__c`. The only door in is Apex Class access to the two controllers above (both
  run in system mode, as all Apex does, but every method independently re-validates the
  token/session before touching any data).
- 5 consecutive wrong OTP attempts lock the Case's questionnaire (`Questionnaire_Locked__c`) until
  a new OTP is requested.

## Manual end-to-end test script

1. Email your Email-to-Case routing address → confirm a Case is created with Status
   **Initial Request** and Record Type **Shop Request**.
2. As an agent, open the Case and try dragging Path to **Send Questionary** without setting
   **Case Type** → expect a validation error.
3. Set Case Type, move Path to **Send Questionary** → confirm the requester receives an email
   with a questionnaire link (inspect it - it should contain `?token=`, not the Case Id).
4. Open the link (try on a phone) → an OTP email should arrive automatically.
5. Enter a wrong code a few times → confirm lockout after 5 attempts; tap **Resend** → confirm the
   *old* code no longer works and the new one does.
6. Enter the correct code → the form should show the questions configured for that Case's
   Case Type, with required fields enforced before Submit is enabled.
7. Submit → Case Status becomes **Answer Received**; `QuestionAnswer__c` records exist, one per
   answered question.
8. Re-open the same link → OTP is requested again, and after verifying, the form renders
   **read-only** with the previously submitted answers pre-filled.
9. Check the page at a 375px-wide viewport and desktop width to confirm layout and tap targets
   hold up.

## Configuring questions

Create `QuestionMaster__c` records (Setup → Object Manager, or a list view) with:
- `Type__c` matching one of the Case Type values (`New Branded Shop` / `New Franchise Shop`)
- `AnswerType__c` driving the rendered control (`Text`, `Option`, `Boolean`, `Date`)
- `Options__c` as a comma-separated list when `AnswerType__c = 'Option'` (enforced by a validation
  rule on the object)
- `Active__c` checked to make it appear on the public form

## Note on Case.Status if this org has other Case processes

The three new Status values (`Initial Request`, `Send Questionary`, `Answer Received`) were added
as **globally active** values on the standard `Case.Status` field (this is required to add values
to a standard picklist at all), then scoped to only appear on the **Shop Request** Record Type via
a dedicated Support Process (`Shop_Request_Support_Process`). If this org already runs other Case
processes on a Record Type with **no** Support Process restriction (e.g. the org default "Master"
record type), those Cases will also see the 3 new values in their Status picklist, since an
unrestricted record type shows every globally active value. If that's a concern, give any other
Case processes their own Support Process too, so each Record Type only shows its own relevant
Status values.

## Known platform constraint

`QuestionAnswer__c.Question_Text__c` is a plain **Long Text Area** field populated by Apex at
submit time, not a true formula field. Salesforce formulas cannot reference a Long Text Area
field (`QuestionMaster__c.QuestionText__c` is one), so a live formula was not possible here. The
practical effect is the same - each answer keeps a permanent snapshot of the question wording -
and it has the added benefit of preserving exactly what the requester was asked even if the
master question's text is edited later.
