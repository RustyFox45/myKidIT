# 👨‍👩‍👧‍👦 myKidIT

**myKidIT** is a cross-platform Flutter application designed to streamline family coordination, household chores, and activity permissions. Built with a clean, feature-first architecture, the app provides dedicated experiences for both parents and children—complete with AI-assisted chore verification, activity approval workflows, and instant role-switching for testing and demos.

---

## ✨ Key Features

* **Dual-Role Experience (Parent & Child Views):**
  * **Parent Dashboard:** Create and assign chores, review AI verification results, approve or decline children's activity requests, and manage household members.
  * **Child Dashboard:** View assigned tasks, submit chore completions, request permission for upcoming activities, and track notifications.
* **Smart Chore Management & AI Verification:**
  * Parents can create custom chore tasks with descriptions and reward/completion details.
  * Includes an integrated AI verification service (`ai_verification_service.dart`) to help validate completed chores.
* **Activity Permission Workflows:**
  * Children can submit structured activity requests (e.g., hanging out with friends, attending events) through a guided form dialog.
  * Parents receive real-time status updates and can approve or deny requests in one tap.
* **Household & Invite System:**
  * Easily set up a new family household or join an existing one using a generated invite code (`invite_code_generator.dart`).
* **Quick Role Persona Switcher:**
  * Built-in persona switcher bar (`role_persona_switcher_bar.dart`) that lets you seamlessly toggle between Parent and Child perspectives to explore the full app experience.

---

## 🛠️ Tech Stack & Architecture

* **Framework:** [Flutter](https://flutter.dev/) (Dart) — targeting iOS, Android, Web, macOS, Windows, and Linux.
* **Architecture:** Feature-First Clean Architecture (`domain`, `data`, and `presentation` layers per feature).
* **State Management & Routing:** Reactive Provider pattern (`*_providers.dart`) and centralized declarative routing (`app_router.dart`).
* **Testing:** Automated MVP widget and logic test suite (`test/my_kid_it_mvp_test.dart`).

---

## 📁 Project Structure

```text
myKidIT-main/
├── lib/
│   ├── main.dart                                 # Application entry point
│   └── src/
│       ├── app.dart                              # Root app widget & theme/router setup
│       ├── core/                                 # Shared app-wide utilities & UI
│       │   ├── config/app_config.dart            # Environment & app configuration
│       │   ├── routing/app_router.dart           # Navigation routes & role redirects
│       │   ├── theme/app_theme.dart              # Color palette & typography
│       │   ├── utils/invite_code_generator.dart  # Household invite code helper
│       │   └── widgets/
│       │       └── role_persona_switcher_bar.dart # Quick Parent/Child view toggle
│       └── features/                             # Modular feature packages
│           ├── auth_and_family/                  # Onboarding, login, & household setup
│           ├── chores/                           # Chore creation, tasks, & AI verification
│           ├── activity_permissions/             # Activity request forms & approvals
│           └── dashboard_and_notifications/      # Parent/Child dashboards & alerts
├── test/
│   └── my_kid_it_mvp_test.dart                   # Automated MVP feature tests
└── pubspec.yaml                                  # Project dependencies & assets
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and added to your PATH.
* An IDE such as VS Code or Android Studio, or a mobile emulator / web browser (Chrome).

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/myKidIT.git
   cd myKidIT
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # Run on your default connected device or browser
   flutter run

   # Or target a specific platform (e.g., Chrome)
   flutter run -d chrome
   ```

4. **Run tests:**
   ```bash
   flutter test
   ```

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome! Feel free to open an issue or submit a pull request if you would like to improve **myKidIT**.