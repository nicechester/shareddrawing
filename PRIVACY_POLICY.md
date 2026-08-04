# Privacy Policy

**Last Updated:** August 3, 2026

## 1. Overview

SharedDrawing is a collaborative drawing application that allows users to create and share real-time drawing canvases. This Privacy Policy explains how we collect, use, and protect your information when you use our app.

## 2. Information We Collect

### 2.1 Authentication Data
- **Anonymous Auth**: When you first open the app, you are automatically assigned a unique anonymous identifier for real-time sync.
- **Sign in with Apple** (optional): If you choose to sign in, we receive:
  - Your email address (if you select "Share Email")
  - A unique user identifier from Apple
  - We do not receive your Apple password or payment information

### 2.2 Drawing Data
- All strokes you create on a canvas (points, colors, brush width, timestamps)
- Canvas metadata (name, creation date, last activity timestamp)
- Information about which user created each stroke

### 2.3 Device & Usage Data
- App crash reports and performance metrics (via Firebase)
- Canvas participation events (join, create, leave)
- We do not collect: device identifiers, location, contacts, photos library, or other sensitive device data

## 3. How We Store Your Data

### 3.1 Firebase Realtime Database
- All drawing data is stored in Google Firebase Realtime Database
- Data is encrypted in transit (TLS) and at rest
- Data is organized by canvas ID; each canvas is accessible only by users with its ID

### 3.2 Data Location
- Data is stored in Firebase's regional servers (data residency depends on your Firebase project configuration)
- See [Firebase Privacy & Security](https://firebase.google.com/support/privacy) for details

## 4. How We Use Your Data

We use your information to:
- Render your strokes and other users' strokes in real-time
- Persist your drawing history
- Authenticate and identify your contributions
- Improve app performance and stability
- Debug crashes and errors

We **do not**:
- Sell your data
- Use your data for advertising or marketing
- Share your data with third parties (except as described below)
- Use your drawings for training AI models

## 5. Third-Party Services

### 5.1 Google Firebase
- Firebase Realtime Database stores all drawing content
- Firebase Authentication handles Sign in with Apple
- Firebase Crashlytics may collect anonymized crash reports
- See [Google Privacy Policy](https://policies.google.com/privacy) for details

### 5.2 Apple Sign-in
- Authentication is handled directly by Apple
- See [Apple Privacy Policy](https://www.apple.com/privacy/) for details

## 6. Data Retention & Deletion

### 6.1 Canvas Data
- Drawing canvases are stored indefinitely unless manually deleted
- To delete a canvas, all participants must stop accessing it; canvases can be manually removed from Firebase

### 6.2 User Data
- Anonymous user accounts are not directly deletable (the identifier persists)
- If you sign in with Apple and delete your account, your email is removed, but your drawing contributions remain (associated with your user ID)
- To request deletion of all your data, contact us at [insert contact email]

### 6.3 Crash Reports
- Firebase Crashlytics data is retained for 90 days by default

## 7. Data Security

- All communication between your device and Firebase uses TLS encryption
- Realtime Database rules restrict writes to authenticated users
- Only users with a canvas ID can read that canvas's data
- We recommend using strong, unique passwords if using Sign in with Apple

## 8. Children's Privacy

SharedDrawing is not intended for users under 13. We do not knowingly collect personal information from children under 13. If we become aware that a child under 13 has provided us with personal information, we will delete such information promptly.

## 9. Your Rights

Depending on your location, you may have the right to:
- Access your personal data
- Correct or update your data
- Delete your data (where applicable)
- Opt out of optional features (e.g., Sign in with Apple)

To exercise these rights, contact us at [insert contact email].

## 10. California Privacy Rights (CCPA)

If you are a California resident, you have the right to:
- Know what personal information is collected, used, and shared
- Delete personal information collected from you
- Opt out of "sales" or "sharing" of personal information

We do not currently engage in the "sale" of personal information as defined by CCPA. For more information, contact us at [insert contact email].

## 11. European Privacy Rights (GDPR)

If you are in the EU, you have rights including access, rectification, erasure, and data portability. Our legal basis for processing is:
- **Performance of a contract** (providing the service)
- **Legitimate interests** (improving the app, preventing abuse)
- **Consent** (Sign in with Apple)

For data subject requests, contact us at [insert contact email].

## 12. Changes to This Policy

We may update this Privacy Policy periodically. We will notify you of material changes by updating the "Last Updated" date and notifying you within the app or via email.

## 13. Contact Us

For questions, requests, or concerns about this Privacy Policy, please contact:

**Email**: [insert contact email]

**Address**: [insert mailing address if applicable]

---

**Note to users**: This is a template privacy policy. Before publishing SharedDrawing, customize the following:
- Contact email address
- Specific Firebase project region and data residency details
- Your company name and legal entity
- Mailing address (if required in your jurisdiction)
- Any applicable disclaimers or local law addendums
