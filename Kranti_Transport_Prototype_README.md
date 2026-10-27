# Kranti Transport (Gold) Prototype

A small demo that shows clients what the Kranti **transport subscription** will do.
It is for **awareness**, not for real use. Nothing here sends real SMS or email.

**What you will see:** a transporter creates a service request, the requester fills a form on their phone, the transporter approves, the other party releases a one-time code at the handover, the transporter enters it, and a sealed receipt (GDRN) is created that anyone can verify.

> **Honest status, please read once.**
> The server and the web pages were tested end to end (34 automatic checks, plus a phone-sized browser walk-through).
> The Flutter app was written and checked for syntax with the real Dart tools, but it could **not be compiled or run** where it was written, because Flutter cannot be downloaded there.
> So you are the first to run it. If `flutter run` shows an error, copy the message and send it back. It will be a small fix.

---

## What is in this folder

| Folder | What it is |
|---|---|
| `server/` | The small back end. It also serves the plain web pages the **requester** and **other party** open on their phones, and the **Demo phone inbox**. |
| `flutter_app/` | The transporter's app (web, Android and iOS from one code base). |

---

## Part 1. One-time installs

You need these on the computer you will use. Use each official page; the steps change over time.

| Install | Why | Where |
|---|---|---|
| **Node.js (LTS version)** | Runs the server | https://nodejs.org |
| **Flutter SDK** | Builds the app | https://docs.flutter.dev/get-started/install |
| **Google Chrome** | Runs the app in a browser, and opens the requester pages | https://www.google.com/chrome |

Only if you want phones:

* **Android emulator:** Android Studio (the Flutter install page explains it).
* **iPhone simulator:** a Mac with Xcode. iOS apps cannot be built on Windows or Linux.

**Check Flutter is ready:** open a terminal and type `flutter doctor`. Fix anything it marks with a red cross for the platform you want (Chrome is enough to start).

---

## Part 2. Start the server (2 commands)

1. Open a terminal **inside the `server` folder**.
2. Type these two commands, one after the other:

```
npm install
npm start
```

`npm install` is only needed the first time.

You should see:

```
Kranti transport prototype server is running.
Open this in your browser: http://localhost:4180
```

3. Open **http://localhost:4180** in Chrome. You should see a page saying the server is running.

Leave this terminal window open. Stop the server any time with `Ctrl + C`.

**Start again with fresh demo data:** stop the server, type `npm run reset`, then `npm start`.

---

## Part 3. Run the app

Do this once, in a **second** terminal (leave the server running).

**Step 1. Make an empty Flutter project.** Open the terminal in the folder that contains `server` and `flutter_app`, then type:

```
flutter create kranti_transport
```

**Step 2. Copy our files into it.** This replaces the project's `lib` folder and `pubspec.yaml`.

*Mac or Linux:*
```
cp -R flutter_app/lib/. kranti_transport/lib/
cp flutter_app/pubspec.yaml kranti_transport/pubspec.yaml
rm -rf kranti_transport/test
```

*Windows (PowerShell):*
```
Copy-Item -Recurse -Force flutter_app\lib\* kranti_transport\lib\
Copy-Item -Force flutter_app\pubspec.yaml kranti_transport\pubspec.yaml
Remove-Item -Recurse -Force kranti_transport\test
```

**Step 3. Go into the project and fetch its one dependency:**
```
cd kranti_transport
flutter pub get
```

**Step 4. Run it. Pick what you want to see:**

| Where | Command |
|---|---|
| In Chrome (easiest, start here) | `flutter run -d chrome` |
| Android emulator (start the emulator first) | `flutter run` |
| iPhone simulator (Mac only; open the Simulator first) | `flutter run` |
| A real phone on the same Wi-Fi | `flutter run` with the phone plugged in |

### Extra step for Android only (2 small edits)

Android blocks plain `http://` addresses and internet access unless you allow them.
Open `kranti_transport/android/app/src/main/AndroidManifest.xml` and make two changes:

1. Add this line **just above** the line that starts with `<application`:
```
<uses-permission android:name="android.permission.INTERNET" />
```
2. Inside the `<application ...` tag, add this attribute:
```
android:usesCleartextTraffic="true"
```
Then run again.

### Extra step for a real iPhone only (if it says it cannot reach the server)

Open `kranti_transport/ios/Runner/Info.plist` and add these lines just before the final `</dict>`:
```
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```
When the phone asks to allow access to the local network, choose **Allow**.

### The server address on the login screen

| Where the app runs | Type this as the server address |
|---|---|
| Chrome on the same computer | `http://localhost:4180` (already filled in) |
| iPhone simulator | `http://localhost:4180` |
| Android emulator | `http://10.0.2.2:4180` |
| A real phone | `http://YOUR-COMPUTER-ADDRESS:4180`, for example `http://192.168.1.20:4180` |

**For a real phone**, start the server with the same address so the links in the demo messages work. Replace the address with your own:

* Mac or Linux: `PUBLIC_URL=http://192.168.1.20:4180 npm start`
* Windows PowerShell: `$env:PUBLIC_URL="http://192.168.1.20:4180"; npm start`

If the phone still cannot connect, your computer's firewall may be blocking it. Allow Node.js on private networks.

**Login (already filled in):** `adnan@xyz.com` and `Password@123`.

---

## Part 4. Try it: the whole story in 6 steps

Keep the **app** and a **Chrome tab** side by side. The Chrome tab plays the requester's and the other party's phones.

| # | Do this | You should see |
|---|---|---|
| 1 | In the app press **Create**. Choose a requester, pick **Load** or **Unload**, press **Send the request link**. | "Request SV-… created." |
| 2 | Open **Demo phone** (in the app, or http://localhost:4180/inbox in Chrome). Click the link in the newest message. | The requester's form, on a phone-sized page. |
| 3 | Fill the form. Use **Save and continue** on each section. Try leaving something wrong on purpose (for example a short GSTIN). | Exact error messages under each field. Finished sections show a tick and fold away. Submit at the end. |
| 4 | Back in the app, wait a few seconds. | A pop-up: "New request to approve" with a countdown. Open it, check the details, press **Accept**. |
| 5 | In the order, choose **driver** and **vehicle**, save, then press **Send for confirmation**. In the Demo phone, click the newest link. | The other party's page. Press **Get my code**. |
| 6 | In the Demo phone, read the 6-digit code. Type it into the order in the app and press **Seal now**. | "Sealed. GDRN … issued." Three receipt emails appear in the Demo phone. Click one to open the verify page. |

**Already-made examples:** the demo data includes a waiting request, one that needs your decision, one that is active and ready for step 5, and one already sealed. The "needs your decision" one only lasts 25 minutes after the server first starts (its pop-up appears soon after you log in). Run `npm run reset` for a fresh set.

---

## What is real, and what is pretend

| Real in this demo | Pretend in this demo |
|---|---|
| Each link has a long random secret. Only a scrambled copy is stored. | SMS. The **Demo phone** stands in for it. |
| Opening a link never changes anything. Changes need a button press. | Email. It is only **recorded**, never sent. |
| The code is made only after the other party presses the button, lasts 10 minutes, allows 3 wrong tries, and is stored scrambled. | There is no PDF, QR code or daily anchor. The verify page shows the sealed record. |
| The transporter's app never shows the code. | No payment or sign-up. `http://localhost:4180/plans` stands in for the separate plans page. |
| A fingerprint of the sealed record is checked on the verify page. | GSTIN is checked for **format only**, not looked up. |

The Demo phone is the only place a code appears, because in real life it goes to the other party's phone and never to the transporter.

---

## For the developers

**Rules this prototype follows (please keep them in the real build)**

* The organisation always comes from the login token on the server, never from the request.
* A GET never changes state. Everything else is a POST, PATCH or DELETE after an explicit tap.
* The code is never returned by any API the transporter can call.
* An unknown, expired or cancelled link returns the same plain "not valid" answer.
* One place decides what is valid, so the form always shows the server's exact error.

**Choices made in this prototype that you should confirm** (any can change)

1. Sections fold and open by tapping the title. They also fold on **Save and continue** once valid.
2. Mandatory: requester email, goods description, number of items, the four dates, and the other party's GSTIN, name, address, pick-up or drop address and mobile. Optional: alternate numbers, unit, weight and the other party's email.
3. The other party's GSTIN and mobile cannot equal the requester's.
4. The requester can edit until the transporter accepts. The 25-minute approval clock starts at the first submission and edits do not reset it.
5. Driver and vehicle can change until the reference receipt is recorded **or** the confirmation is sent. Sending for confirmation needs both to be set.
6. The reference receipt number is optional.
7. The other party's link lasts 24 hours and can be re-sent. A new code can be requested after 60 seconds, at most 5 an hour.
8. The delivery deadline is the end of the expected-delivery window plus 3 days. After that the order is Dormant and cannot be sealed. Revival is not in the prototype.
9. A resend works only after a request has expired. It makes a new link, a new 25 minutes, and keeps the earlier answers.
10. There is deliberately **no "copy link" button** for the transporter, because the link must exist only in the SMS.
11. Public pages show masked mobile numbers and never addresses. GSTIN is shown for now, pending the legal team.

**Run the automatic server test** (from the `server` folder): `node smoke-test.js`. It runs the whole flow plus the safety rules and prints `34 passed`.

**Files**

* `server/server.js`: the whole back end in one file.
* `server/public/`: the requester page (`r.html`), other-party page (`o.html`), Demo phone (`inbox.html`), verify page (`v.html`), plans page and shared look (`css/kranti.css`).
* `flutter_app/lib/`: `ui.dart` (the look), `api.dart`, and one file per screen.

---

## If something goes wrong

| What you see | What to do |
|---|---|
| `npm: command not found` | Install Node.js (Part 1), then open a new terminal. |
| `Cannot reach the server...` in the app | Is the server still running? Is the address right for where the app runs (table in Part 3)? |
| Works in Chrome but not on Android | The two Android edits in Part 3 are missing. |
| The requester link in the Demo phone shows `localhost` but your phone cannot open it | Restart the server with `PUBLIC_URL` set to your computer's address (Part 3). |
| A page says "This link is not valid or has expired" | Links have time limits. Create a new request, or press **Resend link** on an expired one. |
| The pop-up never appears | It appears within about 5 seconds of the requester submitting, once per request. |
| `flutter run` shows a red error | Copy the full message and send it back. |
| You want to start over | Stop the server, `npm run reset`, `npm start`. |
