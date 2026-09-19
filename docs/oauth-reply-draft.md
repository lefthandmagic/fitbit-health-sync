# Reply to: [Action Needed] OAuth Verification Request Acknowledgement

Reply **on the 14 Aug 2026 thread** from API OAuth Dev Verification. Gmail send is blocked from Luna — paste this yourself.

---

Hello Trust & Safety team,

Thank you for the 14 August review. I have addressed each item.

**1. Application name**  
Cloud Console application name is now **Fit Health Sync by Praveen Murugesan** so it uniquely identifies this developer and product (App Store listing remains “Fitbit Health Sync”).

**2. Homepage and privacy on a domain I own**  
Homepage, privacy policy, and terms now live on **https://REPLACE_DOMAIN/** (same host).  
Privacy: **https://REPLACE_DOMAIN/privacy**  
Terms: **https://REPLACE_DOMAIN/terms**  
I verified ownership of the top private domain in Google Search Console with **lefthandmagic@gmail.com**, which is also an owner/editor of this Cloud project. The previous github.io URLs are retired for OAuth branding.

**3. Scope justification**  
The app is an on-device iPhone client. It reads Google Health and writes the user’s chosen metrics into Apple Health. There is no backend that stores Google user data.

- `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly` — user-facing Sync Now / background sync copies **steps** and **active energy** into Apple Health. Google Health has no narrower steps-only scope. We do not request write.
- `https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly` — same path copies **body weight**, **body fat percentage**, and **resting heart rate**. No write / ECG / profile scopes.
- `https://www.googleapis.com/auth/googlehealth.sleep.readonly` — same path copies **sleep**. Sleep is not included in the activity scope.

These three strings are the only Google Health scopes in the iOS client (`GoogleHealthConfig.scopes`) and the only ones configured under Data Access.

**4. Scope discrepancy**  
Code, OAuth authorize URL, and Cloud Console Data Access now match those three readonly scopes exactly. Demonstration video shows the consent screen with Show all services expanded.

**5. Test credentials**  
The app has **no local login**. Reviewers use Google OAuth only. There is no phone-OTP or credit-card gate inside the app.  
Walkthrough: install TestFlight **Fitbit Health Sync** → Home → Connect Google Health → grant the three scopes → Sync Now → open Apple Health and confirm the enabled metrics. Settings controls interval and which of the six metrics write.

Optional test Google account (if you cannot use your own Health data):  
Email: REPLACE_TEST_EMAIL  
Password: REPLACE_TEST_PASSWORD  
(Disable extra 2-Step challenges on that account for the review window.)

**6. Demonstration video**  
Unlisted YouTube: REPLACE_YOUTUBE_URL

**7. CASA AL1**  
I acknowledge the **12 November 2026** ADA-CASA AL1 requirement and have started the lab process.

Please continue the review.

Best regards,  
Praveen Murugesan  
lefthandmagic@gmail.com  
Fit Health Sync / Fitbit Health Sync  
Bundle ID: com.praveenmurugesan.FitbitHealthSync
