# Privacy Policy — Sugar Plus

_Last updated: [FILL IN DATE BEFORE PUBLISHING]_

This policy explains what Sugar Plus ("the app") collects, why, and how to
have it deleted. **Publish this on a public URL (e.g. GitHub Pages) before
submitting to Google Play or the App Store — both require a live privacy
policy link, and Play Console's Data Safety form and Apple's App Privacy
"nutrition label" should match what's written here.**

## What we collect

**Account information** (via Firebase Authentication / Google Sign-In):
email address, display name, and profile photo URL if you sign in with
Google.

**Health data you provide or generate in the app**: blood sugar readings,
either typed in manually or produced by the GlucoScan eye-scan feature
(estimated sugar level, refractive index, Brix value, classification, and
timestamp). This is stored in Cloud Firestore, scoped to your account.

**Eye photos (GlucoScan only)**: when you use GlucoScan, the photo you take
is sent over HTTPS to our analysis server for processing and is **not
stored** — it is held in memory only for the duration of that single
request, then discarded. The server does not persist, log, or retain
uploaded images. Only the resulting numbers (sugar level, refractive index,
Brix, classification) are sent back to the app, and those are what get saved
to your history if you tap "Save."

## What we do not collect

We do not collect location, contacts, device advertising identifiers, or
any data for advertising purposes. We do not sell or share your data with
data brokers or advertisers.

## Third-party services

- **Firebase** (Google): Authentication, Cloud Firestore (database), and
  Firebase Storage. Governed by
  [Google's Privacy Policy](https://policies.google.com/privacy).
- **Google Sign-In**: used only to authenticate you; see the same policy
  above.
- Our GlucoScan analysis server (self-hosted, not a third party) — see the
  eye-photo handling note above.

## Data retention & deletion

Your health readings and account data are retained until you delete them.
You can permanently delete your account and all associated data at any time
from **Profile → Delete Account** in the app. This removes your reading
history and account record immediately, and your Firebase Authentication
account is deleted as part of the same action.

## Medical disclaimer

Sugar Plus, including the GlucoScan feature, is **experimental and not a
medical device**. It is not FDA-cleared or clinically validated, must not be
used to diagnose or manage diabetes, and should never replace a clinical
blood glucose test or professional medical advice.

## Children

Sugar Plus is not directed at children and we do not knowingly collect data
from children under 13 (or the relevant age of consent in your region).

## Contact

[FILL IN a support email or contact method before publishing]

## Changes to this policy

We'll update the "Last updated" date above when this policy changes
materially.
