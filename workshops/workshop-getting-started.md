# Omnicom DMV Snowflake Sessions — Getting Started

This workshop is hands-on. You get your own Snowflake account, preloaded with sample advertising data, and follow along in SQL during each session.

Accounts are temporary. They stay up for the workshop series (about three weeks) so you can practice after class. Do not put real client or personal data in these accounts.

## 1. Claim your Snowflake account

1. Open the DataOps.live instructions page:

   <https://go.dataops.live/omnicom-dmv-snowflake-sessions/instructions>

2. Create a DataOps.live account, or sign in if you already have one.
3. Follow the prompts to claim your workshop Snowflake account. You will get a Snowflake login URL, username, and a one-time password (or an activation link).

Keep that login page open. You will need it for the next step.

## 2. Set up MFA (required before you can work)

Snowflake requires multi-factor authentication on a new account. This is the step that trips people up. Do it **once**, before the session starts if you can.

### Why you have to do this

Snowflake accounts must use strong authentication. A password alone is not enough. MFA is a second check — usually an approval on your phone — so someone who only has your password still cannot sign in.

These workshop accounts are brand new. Snowflake will force MFA enrollment on your first login. You cannot skip it.

### What to use

Use an authenticator app on your phone. Duo is the default Snowflake prompts you toward. Microsoft Authenticator or Google Authenticator also work if Duo is a problem.

You need:

- Your phone
- The authenticator app installed before you start
- About 5 minutes

### How to enroll

1. Open the Snowflake URL from DataOps.live and sign in with the temporary password.  Bookmark the Snowflake URL for later sessions.
2. Snowflake may ask you to set a new password. Pick one you will remember for all the workshop sessions. This password is only for this temporary account.
3. When prompted to set up MFA / Duo:
   - Choose the authenticator app option (not SMS if you can avoid it — SMS codes are slower in a live session).
   - Scan the QR code with Duo or your authenticator app.
   - Enter the 6-digit code the app shows to confirm enrollment.
4. If Snowflake offers backup codes, save them somewhere you can find them (Notes app, password manager). You may need them if you switch phones mid-workshop.
5. Sign out and sign back in once to confirm the second prompt works.

### If MFA enrollment fails

- **QR code will not scan:** On the enrollment screen, use the “enter key manually” / “can’t scan” option and type the setup key into the authenticator app.
- **Wrong code:** Codes refresh every 30 seconds. Wait for a new one, type it immediately, and check that your phone’s clock is set automatically.
- **Duo blocked on your phone:** Use Microsoft Authenticator or Google Authenticator instead of the Duo app. The QR code is a standard TOTP code.
- **You enrolled, then got locked out:** Use a backup code if you saved one. If you did not, contact the session facilitator — the account can be reset. Do not create a second DataOps.live account; that will not fix MFA on the first Snowflake user.
- **Corporate phone policy blocks authenticator apps:** Tell the facilitator before the session. We can sort it out offline. Do not wait until the lab starts.

After MFA works, you should land in Snowsight (the Snowflake web UI).

## 3. Load the session SQL into Snowsight

Worksheets live inside your account. There is no shared worksheet we can push to everyone, so you copy the SQL in once per session.

1. In Snowsight, open **Projects → Workspaces**.
2. Click **Add New** and choose **SQL file**.
3. Name it for the session, for example `session-a.sql`.
4. In a new browser tab, open the worksheet for that session:

   | Session | Topic | SQL file |
   | --- | --- | --- |
   | A | Foundations | <https://richmurnane.github.io/richmurnane-public-files/workshops/session-a-worksheet.sql> |
   | B | Governance | _link added before session B_ |
   | C | Data Engineering | _link added before session C_ |
   | D | Cortex AI | _link added before session D_ |
   | E | Performance | _link added before session E_ |

5. The browser will usually **download** the `.sql` file. Open it in a text editor (TextEdit, Notepad, VS Code — not Word).
6. Select all, copy, and paste into the SQL file you created in the workspace.
7. Run queries **one at a time**. Read the comments. They tell you what to change roles for, what to expect, and where to try it yourself.

If the file opens as a wall of text in the browser instead of downloading, select all on that page and paste it the same way.

## 4. Use Cortex Code during the lab

Cortex Code (sometimes labeled Coco) is the assistant built into Snowsight.

- Look for the blue Snowflake / star icon on the **right-hand side** of the screen.
- Open it if you get stuck on a query, an error message, or a concept from the comments.
- Paste the error text. Ask it to explain the next step. Do not paste real customer data.

## Before the first session — checklist

- [ ] Claimed a Snowflake account from the DataOps.live link
- [ ] Set a password you can remember
- [ ] MFA enrolled and tested with a second login
- [ ] Authenticator app still on your phone
- [ ] Backup codes saved, if Snowflake gave you any
- [ ] Opened **Projects → Workspaces** at least once so the UI is familiar

Doing MFA the night before is the difference between starting the lab on time and spending the first 15 minutes on a phone prompt.
