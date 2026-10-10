# Web steps

Apple has no API for these, so they happen in a browser. The first two are one-time; the third is once per app.
An agent that can drive your browser (for example Claude Code with [Claude in Chrome](https://claude.com/chrome)) can do all three; the notes for agents are in the boxes.

| Step | How often | Can an agent do it? |
| --- | --- | --- |
| [Find your Team ID](#find-your-team-id) | once | yes |
| [Create the App Store Connect API key](#create-the-app-store-connect-api-key) | once | yes, except the first-time access request and 2FA |
| [Create the app record](#create-the-app-record) | once per app | yes |

## Rules for an agent driving the browser

Applies to every section below.

- Use the human's normal browser profile, where they're already signed in to Apple. Open a **new tab** and don't take over existing tabs.
- **Never type passwords.** If Apple asks for a sign-in or a 2FA code, stop and ask the human to complete it in that tab, then continue.
- Don't accept legal agreements (Program License Agreement, API terms) for the human. Ask them to click through.
- Downloads land in `~/Downloads` **of the computer running the browser**, which may not be the Mac that builds
  (for example when you work on the Mac over SSH). If so, copy the file across first (e.g. `scp other-host:Downloads/AuthKey_KEYID.p8 /tmp/`), then `mainline setup --key /tmp/AuthKey_KEYID.p8`.
  Check which browser is connected before downloading. Move secrets to `~/.mainline/` right away (see below).
- Avoid buttons that open browser confirmation dialogs (e.g. **Revoke**). They block the browser automation.

---

## Find your Team ID

1. Go to <https://developer.apple.com/account> and sign in.
2. Scroll to **Membership details**.
3. Copy **Team ID**: 10 characters, letters and digits (e.g. `ABCDE12345`).
4. Save it:

   ```sh
   mainline setup --team ABCDE12345
   ```

> **Agents:** read the Team ID from the page text (no clicking needed), then run `mainline setup --team <it>`.

---

## Create the App Store Connect API key

1. Go to <https://appstoreconnect.apple.com> → **Users and Access**.
2. Open the **Integrations** tab → **App Store Connect API** (left sidebar) → **Team Keys**.
3. **First time only:** if you see **Request Access**, the Account Holder must click it and accept the terms. 🧑
4. Click **Generate API Key** (or **+** if keys already exist).
   - **Name:** `mainline`
   - **Access:** `Admin` (why: see "Why Admin?" in [setup, step B3](setup.md#b3-app-store-connect-api-key))
   - Click **Generate**.
5. Note two values from the page:
   - **Issuer ID**: the UUID shown above the keys table (copy button next to it).
   - **Key ID**: in the new key's row.
6. Click **Download** in the new key's row. ⚠️ **Apple allows only one download.** Keep the file safe.
7. In the terminal (replace `KEYID` and the issuer):

   ```sh
   mainline setup --key ~/Downloads/AuthKey_KEYID.p8 --issuer 00000000-0000-0000-0000-000000000000
   rm ~/Downloads/AuthKey_KEYID.p8      # mainline keeps its own copy in ~/.mainline
   ```

> **Agents:** open a new tab at `https://appstoreconnect.apple.com/access/integrations/api`.
> Stop and hand over for **Request Access**/terms or any 2FA prompt. After **Download**, the file is
> `~/Downloads/AuthKey_<KEYID>.p8`. Read the Issuer ID from the page, run the `mainline setup` command above right away, and
> never print the key's contents. `setup` finishes by running `mainline doctor`.
> If the download was lost, don't try to download again (Apple won't allow it). Ask the human to revoke the key and generate a new one.

---

## Create the app record

Apple's API can't create app records, so this happens once per app, after `mainline register <app>` has
registered the bundle ID. `register` (and `ship`) print the exact values when the record is missing (exit 10):

```
  URL            https://appstoreconnect.apple.com/apps  →  "+"  →  New App
  Platforms      iOS
  Name           Tally
  Primary Lang.  English (U.S.)
  Bundle ID      Tally - com.example.tally
  SKU            tally
  User Access    Full Access
```

1. Go to <https://appstoreconnect.apple.com/apps>.
2. Click **+** (next to "Apps") → **New App**.
3. Fill in the form:
   - **Platforms:** check **iOS**.
   - **Name:** `ASC_APP_NAME` from `app.env`. Max 30 characters, and it **must be unique across the entire App Store**.
   - **Primary Language:** from `PRIMARY_LOCALE` (e.g. English (U.S.)).
   - **Bundle ID:** choose `<DISPLAY_NAME> - <BUNDLE_ID>` from the dropdown. It only appears after `mainline register` has registered the bundle ID. If it's missing, run `register` and reload the page.
   - **SKU:** `SKU` from `app.env`.
   - **User Access:** **Full Access**.
4. Click **Create**.
5. Back in the terminal: `mainline register <app>` should now exit 0 with `✓ ready to ship`.

**Name already taken?** App Store Connect says the name is already in use. Try, in order:
- add a descriptor: `Tally Counter`, `Tally: Count Anything`
- add a brand: `Tally by <your name>`
- shorten or rephrase

Then put the accepted name in `ASC_APP_NAME` in `app.env` so the repo matches the store. The home-screen name (`DISPLAY_NAME`) can stay short; only the store name has to be unique.

> **Agents:** run `mainline register <app>` first and use the values it prints.
> Open a new tab at `https://appstoreconnect.apple.com/apps`, click **+** → **New App**, fill each field, and click **Create**.
> The **Primary Language** and **Bundle ID** dropdowns are native `<select>`s that ignore programmatic value-setting and
> mouse clicks on the open list. Select by the visible label, or use the keyboard and verify the selected value.
> Dropdown order can change; confirm the language and exact bundle ID before clicking **Create**.
> After **Create** the dialog closes, and the page may not navigate. If the name is rejected, try the fallbacks above,
> asking the human if the name matters to them, and update `ASC_APP_NAME`. Confirm with `mainline register <app>` (exit 0).
