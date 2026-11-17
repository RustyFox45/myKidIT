# MyKidIT — AI Agent Source of All Truth (`AGENTS.md`)

> **Purpose of this Document**: This file is the single, authoritative **Source of All Truth** for all AI coding agents and developers working on the **MyKidIT** Flutter project (`my_kid_it`). Every architectural decision, state management pattern, data model, and feature implementation must adhere to this specification.

---

## 1. Project Overview & Product Context

**MyKidIT** is a cross-platform family task management, activity permission, and parental consistency application built for iOS, Android, and Web.

### Core Value Proposition: Automated Task-Gating
Customer validation research (CS 405) established that **70.4% of parents** cite children forgetting or ignoring daily chores—and the resulting parental nagging—as their #1 daily household friction point, especially in **3+ child households** and **co-parenting / divorced households**.

MyKidIT eliminates nagging through **automated task-gating**:
1. Parents assign chores and mark critical chores with a **Prerequisite Flag**.
2. Children complete chores and toggle status to request parental sign-off (uploading optional/required **photo proof**, which can be evaluated via **AI Sign-Off** or manual parent review).
3. When a child fills out an **Activity Permission Request** (destination, time window, host parent/contact, transportation), an **Automated Chore Audit** checks whether all prerequisite chores are completed and signed off before unlocking or submitting the request.
4. Households support **Multi-Parent Linking** with configurable **Approval Rules (1 Parent vs. 2 Parents)** and **Real-Time Status Sync** so both parents and children always see live statuses (e.g., `Pending — 1 of 2 parents approved`, `Approved`, `Denied`, or `Changes Requested`).

---

## 2. Tech Stack & Project-Crucial Attributes

All AI agents working on this repository must use the following stack and conventions:

| Layer | Technology / Package | Notes & Rules for Agents |
| :--- | :--- | :--- |
| **Framework** | **Flutter** (Dart 3.x, Material 3) | Target platforms: iOS, Android, Web (`my_kid_it`). |
| **State Management** | **Riverpod** (`flutter_riverpod`, `riverpod_annotation`) | **Mandatory.** Use `Notifier` / `AsyncNotifier` / `StreamNotifier`. Never use `Provider` (legacy), `Bloc`, or `GetX`. Avoid stateful business logic inside `StatefulWidget`. |
| **Navigation / Routing** | **`go_router`** | Role-aware declarative routing integrated with Riverpod auth/household state via a router `Provider`. |
| **Backend & Real-Time** | **Supabase** (`supabase_flutter`) | PostgreSQL database with Row-Level Security (RLS), Supabase Auth, Supabase Storage (chore proof photos), and Supabase Realtime (live chore & permission status sync). |
| **Push Notifications** | **Supabase Edge Functions + Push Service** | Real-time push alerts for chore sign-off requests, activity requests, co-parent approvals, and denials/change requests. |
| **AI Photo Verification** | **Gemini Flash Vision API** (via Supabase Edge Function) | Evaluates uploaded chore proof photos against chore title/description and returns structured JSON (`{approved, confidence, feedback}`). |
| **Local Media / Camera** | **`image_picker`** | Used by child accounts to capture/upload photo proof of completed chores. |

---

## 3. Architecture & Directory Structure

Agents must follow a **Feature-First Clean Architecture** paired with **Riverpod**. Keep UI widgets dumb/reactive (`ConsumerWidget` / `ConsumerStatefulWidget`), keep business logic inside Riverpod `Notifier` / `AsyncNotifier` controllers, and isolate external API/database calls inside Repository classes.

```text
lib/
├── main.dart
└── src/
    ├── app.dart                         # Root MaterialApp.router + ProviderScope
    ├── core/
    │   ├── config/                      # Env variables, Supabase/API initialization
    │   ├── routing/                     # go_router configuration & role-based guards
    │   ├── theme/                       # Material 3 color schemes, typography, spacing
    │   ├── utils/                       # Date/time formatters, invite code generators
    │   └── widgets/                     # Shared reusable UI components (buttons, badges, cards)
    └── features/
        ├── auth_and_family/             # MVP Feature 1: Roles, Household Pairing, Multi-Parent Link
        │   ├── data/                    # AuthRepository, HouseholdRepository
        │   ├── domain/                  # AppUser, Household, AccountRole models
        │   └── presentation/            # Login, Role Selection, Pairing/Invite screens & Notifiers
        ├── chores/                      # MVP Feature 2: Chore Engine, Toggle, Photo/AI Sign-Off, Prerequisite Flag
        │   ├── data/                    # ChoreRepository, AiVerificationService, PhotoStorageService
        │   ├── domain/                  # ChoreTask, ChoreRepetition, ChoreStatus models
        │   └── presentation/            # Parent Task Creator, Child Chore List, Photo Proof & Sign-Off UI
        ├── activity_permissions/        # MVP Feature 3: Permission Request Form, Chore Audit, 1-vs-2 Parent Rules
        │   ├── data/                    # ActivityRequestRepository
        │   ├── domain/                  # ActivityRequest, ChoreAuditResult, ApprovalRule, ParentDecision
        │   └── presentation/            # Child Request Form, Prerequisite Gate Banner, Parent Review Modal
        └── dashboard_and_notifications/ # MVP Feature 4: Real-Time Status Dashboard & Push Notifications
            ├── data/                    # NotificationService, RealtimeSyncService
            ├── domain/                  # AppNotification, DashboardSummary
            └── presentation/            # Parent Dashboard, Child Status Dashboard, Notification Feed
```

---

## 4. Core Domain Models (Source Schema)

Agents must maintain immutable Dart models (with `copyWith`, `toJson`, `fromJson`, `==`, and `hashCode`).

### 4.1 `AppUser` & `AccountRole`
* `id` (`String` - UUID)
* `email` (`String?`)
* `displayName` (`String`)
* `role` (`enum AccountRole { parent, child }`)
* `householdId` (`String?` - currently linked household)
* `avatarUrl` (`String?`)

### 4.2 `Household` & `ApprovalRule`
* `id` (`String` - UUID)
* `name` (`String`)
* `childInviteCode` (`String` - 6-character code/QR payload to pair a child account)
* `parentInviteCode` (`String` - 6-character code/QR payload to link a co-parent)
* `parentIds` (`List<String>`)
* `childIds` (`List<String>`)
* `defaultApprovalRule` (`enum ApprovalRule { oneParent, twoParents }`)

### 4.3 `ChoreTask`
* `id` (`String` - UUID)
* `householdId` (`String`)
* `assignedChildId` (`String`)
* `createdByParentId` (`String`)
* `title` (`String`)
* `description` (`String`)
* `repetition` (`enum ChoreRepetition { once, daily, weekly, weekdays, custom }`)
* `dueDate` (`DateTime?`)
* `isPrerequisite` (`bool` — **Crucial:** If `true`, this chore gates new Activity Permission Requests until completed/approved)
* `requiresPhotoProof` (`bool`)
* `aiSignOffEnabled` (`bool` — If `true`, AI vision evaluates the uploaded photo proof)
* `status` (`enum ChoreStatus { todo, pendingSignOff, approved, changesRequested }`)
* `proofPhotoUrl` (`String?`)
* `aiVerificationConfidence` (`double?`)
* `aiVerificationFeedback` (`String?`)
* `parentReviewerId` (`String?`)
* `parentFeedback` (`String?`)

### 4.4 `ActivityRequest`
* `id` (`String` - UUID)
* `householdId` (`String`)
* `childId` (`String`)
* `activityDestination` (`String` — Where the child is going / what they are doing)
* `startTime` (`DateTime` — Start of time window)
* `endTime` (`DateTime` — End of time window)
* `hostParentName` (`String` — Supervising/host adult name)
* `hostParentContact` (`String` — Phone number / contact info of host parent)
* `transportation` (`String` — How the child is getting there and back)
* `prerequisiteAuditPassed` (`bool` — Result of automated chore audit at submission)
* `incompletePrerequisiteChoreIds` (`List<String>`)
* `approvalRule` (`enum ApprovalRule { oneParent, twoParents }`)
* `parentDecisions` (`Map<String, ParentDecision>` — Maps `parentId` to `{status: approved | denied | changesRequested, comment, timestamp}`)
* `overallStatus` (`enum ActivityRequestStatus { blockedByPrerequisites, pending, awaitingSecondParent, approved, denied, changesRequested }`)

---

## 5. MVP Features & Implementation Specification (from "MVP CS 405")

When implementing features, agents must follow the specifications below in order.

### Feature 1: Role-Based Access and Family Setup
1. **1.1 Account Roles (`parent` vs. `child`)**:
   * During onboarding/registration, users select whether they are setting up a **Parent Account** or a **Child Account** (or a Parent creates a managed Child profile and pairs the child's device).
   * Expose `currentUserProvider` (`StreamProvider<AppUser?>`) and `currentAccountRoleProvider` (`Provider<AccountRole?>`) in Riverpod.
   * Use `go_router` redirect guards so children only access Child UI views and parents access Parent UI views.
2. **1.2 Household Pairing (Parent to Child)**:
   * Parents can generate a unique **Child Pairing Code** (or QR code) for their household.
   * Children enter the pairing code on first login to join the `Household`, adding their `user.id` to `household.childIds`.
3. **1.3 Multi-Parent Link (Parent to Parent)**:
   * Parents can invite a spouse or co-parent using a separate **Co-Parent Invite Code / Link**.
   * Joining via a Co-Parent code adds the second parent to `household.parentIds` with full parental permissions and enables 2-parent approval workflows.

### Feature 2: Core Chore and Task Engine
1. **2.1 Task Creation**:
   * Parents can create and edit chores with:
     * `title` & `description`
     * `assignedChildId` (supports multi-child households seamlessly)
     * `repetition` (`once`, `daily`, `weekly`, `weekdays`) and optional `dueDate`
     * `isPrerequisite` toggle (marks chore as required before requesting activities)
     * `requiresPhotoProof` toggle & `aiSignOffEnabled` toggle
2. **2.2 Child Status Toggle (Asking Parents to Sign Off)**:
   * Children view their assigned chores grouped by **Prerequisite Chores** (highlighted at top) and **Standard Chores**.
   * When a child finishes a chore, they tap **"Ask for Sign-Off"** (attaching a photo via `image_picker` if `requiresPhotoProof == true`), transitioning the chore from `ChoreStatus.todo` to `ChoreStatus.pendingSignOff`.
3. **2.3 Parental Sign-Off (Optional Photo Proof & AI Sign-Off)**:
   * **Manual Parental Sign-Off**: Parents receive a sign-off prompt, inspect the photo proof (if provided), and tap **Approve** (`ChoreStatus.approved`) or **Request Redo** (`ChoreStatus.changesRequested` with a note).
   * **AI Sign-Off**: If `aiSignOffEnabled == true` and photo proof is uploaded, `AiVerificationService` analyzes the photo against the chore title/description (e.g., "Clean bedroom floor and make bed"). If the AI confidence meets the threshold, it can auto-approve (`ChoreStatus.approved`) or pre-grade the chore for 1-tap parent confirmation.
4. **2.4 Prerequisite Flag**:
   * Any chore with `isPrerequisite == true` that is **not** in `ChoreStatus.approved` for the current cycle acts as a hard or configurable gate on the child's **Activity Permission Workflow**.

### Feature 3: Activity Permission Workflow
1. **3.1 Activity Permission Request Form**:
   * Child fills out a structured form with four mandatory sections:
     1. **Activity / Destination** (e.g., "Soccer practice at Riverside Park" or "Hangout at Jake's house")
     2. **Time Window** (Start Date/Time and End Date/Time picker)
     3. **Host Parent / Contact** (Name and phone number of responsible adult)
     4. **Transportation** (Who is driving there and who is driving back)
2. **3.2 Automated Chore Audit**:
   * **Real-Time Provider Check**: Create a Riverpod provider `choreAuditProvider(String childId)` that watches the child's active chores where `isPrerequisite == true`.
   * Before the child can submit an Activity Request (or upon submission), the **Automated Chore Audit** checks if any prerequisite chores are incomplete (`status != ChoreStatus.approved`).
   * If any prerequisite chore is incomplete/unapproved:
     * The UI displays a clear **Prerequisite Audit Alert** listing the exact chores that still need completion or parental sign-off, blocking submission (or flagging it to parents as `blockedByPrerequisites`) until resolved.
3. **3.3 Approval Rule Setting (1 Parent vs. 2 Parents)**:
   * Parents can configure the household (or per-request) rule:
     * **1-Parent Rule (`ApprovalRule.oneParent`)**: A single parent's approval immediately transitions the request to `ActivityRequestStatus.approved`.
     * **2-Parent Rule (`ApprovalRule.twoParents`)**: Ideal for co-parenting or high-consistency households. When Parent A approves, the status becomes `ActivityRequestStatus.awaitingSecondParent` ("Pending — 1 parent hasn't approved yet"). Only when Parent B also approves does it become `ActivityRequestStatus.approved`. If either parent denies or requests changes, the status updates immediately.

### Feature 4: Real-Time Notifications & Status Sync
1. **4.1 Push Notifications**:
   * Trigger real-time notifications for:
     * Child $\rightarrow$ Parent(s): Chore sign-off requested (with photo preview), New Activity Permission Request submitted.
     * Parent $\rightarrow$ Co-Parent: "Parent 1 approved [Child]'s activity request — waiting for your approval."
     * Parent $\rightarrow$ Child: Chore approved/redo requested, Activity request Approved / Denied / Changes Requested.
2. **4.2 Status Dashboard**:
   * Synchronized in real time via Riverpod `StreamProvider` / `StreamNotifier` backed by Supabase Realtime channels.
   * **Activity Requests Status Section**:
     * Clearly displays badge states: `Pending`, `1 of 2 Parents Approved (Waiting on [Parent Name])`, `Approved`, `Denied`, or `Changes Requested`.
   * **Chores & Prerequisites Status Section**:
     * Displays progress bar of daily chores and a dedicated **"Activity Unlock / Prerequisite Status"** indicator (`All Prerequisites Complete — Ready to Request Activities!` vs. `2 Prerequisite Chores Remaining`).
   * **Denial of Request / Changes Requested Workflow**:
     * When a parent denies a request or selects **Request Changes** (e.g., "Need host parent's phone number" or "Come home by 8:00 PM instead of 9:30 PM"), the parent's note is shown prominently on the Child Dashboard, allowing the child to edit and resubmit the request without starting over.

---

## 6. Riverpod & Coding Guidelines for AI Agents

1. **Always Use Riverpod**:
   * Wrap the root app in `ProviderScope`.
   * Prefer `AsyncNotifierProvider` / `NotifierProvider` and `StreamProvider` for reactive data flows.
   * Keep providers in `*_providers.dart` or `*_controller.dart` inside each feature's `presentation/` or `data/` folder.
   * Use `ref.watch` inside `build()` methods to reactively rebuild UI on state changes; use `ref.read` inside button callbacks (`onPressed`, `onSubmitted`).
2. **Handle Loading & Error States Gracefully**:
   * Always handle `AsyncValue` states using `.when(data: ..., loading: ..., error: ...)` in the UI so users never see unhandled exceptions or frozen screens.
3. **Offline / Mock-First Development Support**:
   * Define abstract Repository interfaces (e.g., `abstract class ChoreRepository`) with both a `SupabaseChoreRepository` and an in-memory/mock `MockChoreRepository` (injected via Riverpod provider overrides) so features can be tested and demoed immediately even before backend credentials are supplied.
4. **Update This File**:
   * Whenever a feature from Section 5 is completed or an architectural decision changes, update the checklist in Section 7 below.

---

## 7. Implementation Checklist & Current Status

- [x] Stub brand-new empty Flutter project (`my_kid_it`)
- [x] Create `AGENTS.md` Source of All Truth specification
- [x] Configure dependencies in `pubspec.yaml` (`flutter_riverpod`, `go_router`, `supabase_flutter`, `image_picker`, `intl`, `uuid`)
- [x] **Feature 1**: Role-Based Access & Family Setup (Parent/Child roles, Household pairing via `KID405`, Multi-parent linking via `COP405`)
- [x] **Feature 2**: Core Chore & Task Engine (Task creation, Child sign-off toggle, Photo/Gemini AI sign-off, Prerequisite flag)
- [x] **Feature 3**: Activity Permission Workflow (Request form, Automated Chore Audit `choreAuditProvider`, 1-vs-2 Parent approval rule)
- [x] **Feature 4**: Real-Time Notifications & Status Sync (Push notifications, Live Status Dashboard, Denial/Changes Requested loop)
- [ ] Wire live Supabase project credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) and deploy `verify-chore-photo` Gemini Flash Edge Function

