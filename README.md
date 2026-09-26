# Hisabify 👛

> **Shared Expenses, Made Easy.**  
> Effortlessly track, split, and settle expenses with roommates, friends, and travel groups. No more awkward money talks!

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://vercel.com)

---

## 🌐 Live Deployments

* **Official Website:** [hisabify.aadarshapandit.com.np](https://hisabify.aadarshapandit.com.np)
* **Web App (Live):** [app.hisabify.aadarshapandit.com.np](https://app.hisabify.aadarshapandit.com.np)

---

## ✨ Features

* 👥 **Flat & Group Management:** Create a flat or circle, invite members with join codes, and manage multiple shared spaces.
* 💸 **Instant Expense Splitting:** Add expenses with customizable split options (equal, exact shares, custom).
* 📊 **Smart Balance & Settlement:** Automatically calculates minimum transaction debts so settling up requires zero guesswork.
* ⚡ **Real-Time Sync:** Powered by Cloud Firestore for instant live updates across all members' devices.
* 📱 **Cross-Platform:** Built with Flutter for Web, Android, and iOS.
* 🎨 **Stunning Landing Page:** Dedicated modern, responsive marketing site located in `marketing_site/`.

---

## 🏗️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend & Database:** Firebase Authentication, Cloud Firestore
* **Hosting:** 
  * App: Firebase Hosting / Vercel (`app.hisabify.aadarshapandit.com.np`)
  * Marketing Website: Vercel (`hisabify.aadarshapandit.com.np`)
* **State Management:** Riverpod / Provider

---

## 📂 Project Structure

```text
├── android/            # Android native configuration
├── ios/                # iOS native configuration
├── lib/
│   ├── core/           # Constants, themes, utils, formatters
│   ├── features/
│   │   ├── auth/       # Authentication, login, signup, roles
│   │   ├── flat/       # Flat management, invite/join
│   │   └── home/       # Activity, analytics, balances, expenses
│   └── main.dart       # App entrypoint
├── marketing_site/     # High-fidelity landing page (HTML/CSS/Assets)
└── web/                # Flutter web build configuration
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
* [Dart SDK](https://dart.dev/get-dart)
* [Firebase CLI](https://firebase.google.com/docs/cli)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Aadarshttech/hisabify.git
   cd hisabify
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the Flutter Web App:**
   ```bash
   flutter run -d chrome
   ```

4. **Preview the Marketing Website:**
   Open `marketing_site/index.html` in your web browser.

---

## 👨‍💻 Author

**Aadarsha Pandit**  
* Portfolio: [aadarshapandit.com.np](https://aadarshapandit.com.np)  
* GitHub: [@Aadarshttech](https://github.com/Aadarshttech)

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
