# Privacy Policy — femm

**Effective date:** 3 November 2026  
**App:** femm (`com.femm.femm_app`)  
**Operator:** Peter Kwan  
**Contact:** [peterkwkwan@gmail.com](mailto:peterkwkwan@gmail.com)

This Privacy Policy describes how **femm** (“we”, “us”) collects, uses, stores, and shares information when you use the femm mobile app and related practitioner portal (the “Service”).

femm is an early **MVP / prototype** care-navigation product for menopause-related journeys in **Hong Kong**. It helps you upload lab PDFs, answer spend and symptom questions, see a rule-based clinical match and optional upsell suggestions, and (if you confirm a booking) share a pre-visit summary with a booked practitioner. **It is not a medical device, not a diagnosis, and not medical advice.**

Live HTML version (for Google Play and other store listings):  
[https://peterkwkwan.github.io/femm/privacy/](https://peterkwkwan.github.io/femm/privacy/)

---

## 1. Who this policy covers

- **Users** of the Android app who sign in with Google, upload labs, and complete Path A intake.
- **Practitioners** who sign in to the web portal with Google to view booking summaries for appointments linked to their clinic.

The Service is intended for adults. It is **not directed at children under 13**, and we do not knowingly collect personal data from children.

---

## 2. Information we collect

### 2.1 Account and authentication (Google Sign-In + Supabase Auth)

We use **Google Sign-In** and **Supabase Auth**. When you sign in, we may receive and store:

- Google account email address  
- Display name (if provided by Google)  
- A unique user identifier issued by our auth provider  
- Authentication tokens / session data needed to keep you signed in  
- Role in our system (`user` or `practitioner`) and, for practitioners, a linked clinic id when applicable  

We do **not** receive or store your Google password.

### 2.2 Lab PDFs and extracted lab data (health-related)

If you upload a lab PDF, we store:

- The **original PDF file** in a **private** Supabase Storage bucket (`lab-pdfs`), under a path scoped to your user id  
- Metadata such as original filename, upload status, and timestamps  
- **Biomarker rows** extracted by our server-side function (name, value, unit, reference range, H/L flag when present), which you can confirm or edit in the app  

Lab PDFs and biomarker data are **sensitive health-related information**. We process them only to provide the care-navigation features you request (confirm labs, matching, booking summary).

### 2.3 Intake answers (spend and symptoms)

We store your Path A session data, including:

- Selected spend categories (for example skincare/aesthetics, gym/physio, supplements, wellness/spa, mental health, private GP)  
- Selected menopause-related **symptom** chips  
- Completion timestamps for those steps  

### 2.4 Matching, holds, and bookings

We store rule-based match results, hold/booking records (clinical and/or upsell), slot times, partner/clinic references, and confirmation state needed to run the MVP demo flow.

### 2.5 Practitioner summary packs (Path C)

If you confirm a booking, we generate a **summary pack** that may include goals/symptoms snapshot, spend buckets, match reason, flagged labs, lab details, patient email/display name, slot time, and a pointer to the original lab PDF. That pack is readable by **you** and by the **booked practitioner** for that clinic appointment.

### 2.6 Technical and operational data

Our backend (Supabase) and Google’s sign-in services may process standard technical data such as IP address, device/app identifiers, request logs, and security/auth events as part of hosting and authentication. We do **not** currently integrate a separate third-party analytics, advertising, or crash-reporting SDK in the MVP beyond what Google Sign-In / Google Play services and Supabase provide as part of their platforms.

---

## 3. How we use information

We use the information above to:

- Authenticate you and maintain your session  
- Store and extract lab PDFs so you can confirm biomarker rows  
- Run rule-based care-navigation matching and optional same-bucket upsell suggestions  
- Hold and confirm fictional/demo clinic or partner slots in the MVP  
- Generate practitioner pre-visit summaries when you confirm a booking  
- Operate, secure, and debug the Service  
- Respond to support or deletion requests  

We do **not** sell your personal information. We do **not** use lab PDFs or biomarker data for advertising.

---

## 4. Where data is stored and who processes it

| Role | Provider | Purpose |
| --- | --- | --- |
| App backend (Auth, Postgres database, private file storage, Edge Functions for PDF text extract) | **Supabase** | Host account, profile, intake, booking, and lab data; run extract function |
| Sign-in | **Google** (Google Sign-In / OAuth) | Authenticate users and practitioners |
| App distribution (Android) | **Google Play** | Distribute the app; subject to Google’s terms when you install from Play |

Data is processed on infrastructure operated by these providers (Supabase project region is typically chosen near Hong Kong users, e.g. Southeast Asia / Singapore, when configured that way). Their own privacy policies also apply to processing they perform as platforms.

---

## 5. How we share information

We share information only as needed to run the Service:

- **With Supabase and Google** as processors/platforms described above  
- **With a booked practitioner** (via the authenticated portal): summary pack contents and access to the original lab PDF for that booking  
- **If required by law** or to protect rights, safety, or security  
- **With your direction** (for example if you ask us to export or delete data)  

We do not sell personal data to data brokers. MVP clinic/partner supply may be fictional demo data; sharing with a practitioner still only happens for bookings tied to your account.

---

## 6. Access control and retention

- Lab PDF storage is configured as a **private** bucket with path-based access tied to your user id; practitioners receive booking-scoped access for confirmed Path C packs, not a public link dump.  
- Database tables use row-level security so ordinary users read/write their own rows; practitioners can read packs/bookings for their linked clinic when authorized.  
- We retain account, lab, intake, and booking data for as long as needed to operate the MVP and support your use, unless you ask us to delete it sooner or we delete prototype data as part of resetting demo environments.  
- Auth sessions expire according to Supabase Auth / token lifetime settings.

---

## 7. Your choices and rights

Depending on applicable law (including Hong Kong PDPO expectations for personal data), you may request to:

- Access the personal data we hold about you  
- Correct inaccurate profile information  
- Delete your account and associated personal data (including lab PDFs where still stored)  
- Withdraw from further use by signing out and requesting deletion  

**How to request:** email [peterkwkwan@gmail.com](mailto:peterkwkwan@gmail.com) from the Google account email you use in femm, and tell us what you need (access, correction, or deletion). We will respond within a reasonable time for an MVP operated by a small team.

You can also revoke Google access to femm in your Google Account permissions settings; that stops new Google sign-in until you grant access again, but does not by itself erase data already stored in our Supabase project—email us for deletion.

---

## 8. Security

We use industry-standard platform controls (HTTPS, authenticated APIs, private object storage, database row-level security). No method of transmission or storage is 100% secure. The MVP is a prototype: treat uploaded real lab PDFs as sensitive and only use accounts you control.

---

## 9. International users

The Service is built for a **Hong Kong** prototype audience. If you access it from elsewhere, your information may be processed in regions where our providers operate (for example Southeast Asia and other regions used by Supabase/Google).

---

## 10. Changes

We may update this policy as the product changes. The “Effective date” at the top will change when we publish material updates. Continued use after an update means you accept the revised policy for subsequent use. For Google Play, the privacy policy URL will point at the current public version.

---

## 11. Contact

**Peter Kwan** — femm  
Email: [peterkwkwan@gmail.com](mailto:peterkwkwan@gmail.com)

If you have questions about this policy or your data, contact us at the address above.

---

*This document describes current MVP practices honestly. It is not legal advice. Consider counsel review before a broad public launch beyond internal/closed testing.*
