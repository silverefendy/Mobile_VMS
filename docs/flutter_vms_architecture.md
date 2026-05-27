# Flutter Mobile VMS Architecture Proposal (Frappe v16 / ERPNext v16)

## 1) Full Mobile Architecture Proposal

### 1.1 Architectural Style
Use **Clean Architecture + Feature Modules + API-first**:

- **Presentation**: Flutter UI, routing, view models/controllers.
- **Domain**: entities, use-cases, repository contracts.
- **Data**: API DTOs, mappers, repository implementations, local cache.
- **Core**: shared concerns (network, auth, error handling, storage, logging, feature flags).

This keeps backend (Frappe) as source of truth and prevents UI/business coupling.

### 1.2 Core Runtime Layers
- `AppShell`: bootstraps dependencies, env config, theme, localization, router.
- `SessionManager`: single source for auth state, current user, role set, token/cookie status.
- `ApiClient`: centralized HTTP client with interceptors (auth, retry, logging, unauthorized handling).
- `MenuEngine`: resolves dynamic menu + role permission into navigable app structure.
- `SyncLiteCoordinator`: lightweight offline tolerance (queue + retry + cache invalidation).
- `NotificationGateway`: abstraction ready for FCM/push/local notifications.

### 1.3 Recommended State Management
Use **Riverpod (or Flutter Riverpod + StateNotifier/Notifier)**:
- compile-time safety
- testable providers
- feature-level provider scopes
- easy dependency overrides for QA/tests

Alternative: Bloc is also viable, but Riverpod is lighter for modular DI+state.

### 1.4 Dependency Injection
Use `riverpod` providers as DI container, plus `get_it` only if legacy integration needs service locator.

Pattern:
- `core` providers: `dioProvider`, `secureStorageProvider`, `sessionManagerProvider`
- feature providers: `visitorRepoProvider`, `scanUseCaseProvider`
- environment providers: `appConfigProvider`

### 1.5 Environment Strategy
Use flavor-based config:
- `dev`, `staging`, `prod`
- values from `--dart-define` or encrypted config fetch

Config keys:
- `API_BASE_URL`
- `FRAPPE_API_VERSION` (v1/v2 compatibility toggle)
- `ENABLE_VERBOSE_LOGS`
- `ENABLE_SCAN_SOUND`

No credentials in source control.

---

## 2) Recommended Flutter Project Structure

```text
lib/
  main.dart
  app/
    app.dart
    router/
      app_router.dart
      route_guards.dart
    theme/
      app_theme.dart
      design_tokens.dart
  core/
    config/
      app_config.dart
      env.dart
    constants/
    errors/
      app_exception.dart
      failure.dart
    network/
      api_client.dart
      interceptors/
        auth_interceptor.dart
        retry_interceptor.dart
        unauthorized_interceptor.dart
    auth/
      session_manager.dart
      auth_state.dart
    storage/
      secure_store.dart
      local_db.dart
    offline/
      retry_queue.dart
      connectivity_service.dart
    notifications/
      notification_gateway.dart
    utils/
  shared/
    widgets/
    models/
    extensions/
  features/
    auth/
      data/
      domain/
      presentation/
    menu/
      data/
      domain/
      presentation/
    dashboard/
      data/
      domain/
      presentation/
    scanner/
      data/
      domain/
      presentation/
    visitors/
      data/
      domain/
      presentation/
    approvals/
      data/
      domain/
      presentation/
    activity/
      data/
      domain/
      presentation/
```

Each feature follows:
- `data`: datasource, dto, mapper, repo impl
- `domain`: entity, repo contract, use cases
- `presentation`: screens, controllers/notifiers, UI components

---

## 3) API Integration Strategy (Frappe-Compatible)

### 3.1 API Client
Use `dio` with centralized config:
- base URL from env
- timeout, TLS pinning option (production)
- interceptors for auth + 401 handling + tracing correlation id

### 3.2 Frappe Auth Compatibility
Support both:
1. **Session cookie login** via `/api/method/login`
2. **Token auth** with `Authorization: token api_key:api_secret`

Persist only required secrets in secure storage.

### 3.3 Repository Pattern
Example contracts:
- `AuthRepository`
- `MenuRepository`
- `VisitorRepository`
- `ApprovalRepository`
- `ScannerRepository`

Each repository:
- fetches remote data
- maps DTO to domain model
- manages cache fallback where relevant

### 3.4 Error Model Standardization
Map HTTP/Frappe errors into app-level failures:
- `UnauthorizedFailure`
- `NetworkFailure`
- `ValidationFailure`
- `ServerFailure`

UI always receives typed failures, not raw Dio exceptions.

---

## 4) Dynamic Role-Based Menu Architecture (No Hardcoded Menu)

### 4.1 Backend-driven Menu Model
Create backend endpoint (custom whitelisted method or doctype API):

`GET /api/method/visitor_management.mobile.get_mobile_navigation`

Returns:
- app version compatibility
- role list for user
- navigation groups
- menu items (id, label, route, icon_key, order, required_permissions)
- dashboard cards
- feature flags

### 4.2 Local Menu Resolution Flow
1. Login/session restore success
2. Fetch user profile + roles
3. Fetch menu config
4. Validate against local route registry
5. Persist cached config with version/hash
6. Build nav tabs/drawer and dashboard cards dynamically

### 4.3 Role Handling
Do not map by role name only; use permission keys, e.g.:
- `visitor.scan.checkin`
- `visitor.approval.act`
- `visitor.report.read`

This future-proofs custom roles without app rebuild.

### 4.4 Icon Strategy
Backend sends `icon_key`; app resolves via icon map table.
Unknown keys fall back to default icon safely.

---

## 5) Authentication & Session Architecture

### 5.1 Login Flow
1. User enters username/password
2. `AuthRepository.login()` calls Frappe login API
3. Extract cookie/token metadata
4. Store secrets in secure storage (`flutter_secure_storage`)
5. Fetch user profile, roles, menu config
6. Move to app shell

### 5.2 Session Restore
At startup:
- read secure token/session
- validate by hitting `/api/method/frappe.auth.get_logged_user` (or lightweight ping)
- if valid: restore state
- if invalid: clear session and navigate login

### 5.3 Logout
- call Frappe logout endpoint when possible
- clear secure storage + in-memory providers + retry queue
- navigate to login and reset stack

### 5.4 Unauthorized Handling
Global 401 interceptor:
- pause in-flight requests if needed
- mark session expired
- show non-intrusive banner/dialog
- redirect to login once

---

## 6) Scanner Module Architecture (Production-grade)

### 6.1 Scanner UX
- fullscreen camera preview
- center framing box + high-contrast border
- torch toggle (sticky while open)
- clear status strip (“Ready / Processing / Success / Error”)

### 6.2 Scan Pipeline
`ScannerController` state machine:
- `idle`
- `detecting`
- `processing`
- `cooldown`
- `error`

On QR read:
1. normalize payload
2. duplicate-check (in-memory debounce map, e.g. 2–4 sec)
3. call centralized `ProcessScanUseCase`
4. use vibration/sound by result
5. show compact toast/banner result

### 6.3 Backend Compatibility
Centralize scan APIs in `ScannerRepository`:
- `scanCheckIn(code, gateId, deviceMeta)`
- `scanCheckOut(...)`
- `validateVisitorCode(...)`

This keeps UI independent from backend endpoint evolution.

### 6.4 Tablet + Low-light Optimizations
- larger scan target overlay
- side panel for recent 3 scan results (tablet)
- auto-suggest torch in low luminance

---

## 7) Lightweight Offline Strategy

### 7.1 What to Cache
- session metadata
- menu configuration + dashboard config
- last lists: active visitors, pending approvals (short TTL)

### 7.2 Retry Queue (critical)
Queue write actions when offline/interrupted:
- scan check-in/out
- approval action

Queue item fields:
- idempotency key
- endpoint/action type
- payload
- createdAt
- retry count

Retry policy:
- exponential backoff with max attempts
- manual “Retry Now” in diagnostics screen

### 7.3 UI Behavior Offline
- persistent offline banner
- stale-data badge with timestamp
- disable non-supported write actions or queue them explicitly

No full bidirectional sync yet.

---

## 8) Future Scalability & Customization

### 8.1 Feature Flags
Server-driven flags:
- `enable_reports`
- `enable_manager_dashboard`
- `enable_face_capture`

Use `FeatureFlagService` with cached fallback.

### 8.2 Branding + Theme
Backend config endpoint returns:
- primary/secondary colors
- logo URL
- app display name

Apply at runtime via theme extension and cached assets.

### 8.3 Module Enable/Disable
Menu + feature flags jointly control module visibility.
Modules remain compiled but hidden/disabled operationally.

### 8.4 Notification-ready
Create `NotificationGateway` abstraction now:
- token registration API
- topic/role subscription
- local notification rendering

Later plug FCM without breaking feature modules.

---

## 9) Incremental Implementation Roadmap

### Phase 0 — Foundation (Week 1)
- setup project structure, flavors, lints, CI, Riverpod, Dio
- implement AppConfig + ApiClient + error mapping

### Phase 1 — Auth + Session (Week 1–2)
- login UI
- secure storage token/session
- restore session and logout
- 401 global handling

### Phase 2 — Dynamic Navigation (Week 2)
- backend mobile menu endpoint contract
- menu repository + cache
- role/permission route guards
- dynamic dashboard cards

### Phase 3 — Operational Core (Week 3–4)
- Active Visitors
- Pending Approvals + actions
- Visitor Search + Details
- Recent Activity

### Phase 4 — Scanner Productionization (Week 4)
- fullscreen scanner
- duplicate prevention + feedback haptics/sound
- centralized scan processing
- tablet optimization

### Phase 5 — Offline Lite + Stability (Week 5)
- retry queue for scans/approvals
- offline banners + stale indicators
- observability (crash + analytics + API latency)

### Phase 6 — Customization + Notifications (Week 6)
- feature flags
- runtime branding/theme
- notification gateway + push registration skeleton

### Phase 7 — Hardening & Release
- penetration/security checks
- role matrix test coverage
- device matrix QA (low-end Android + tablets)
- playstore-ready build/signing pipeline

---

## Suggested Frappe API Contract Additions (Minimal, Compatible)

1. `mobile.get_mobile_bootstrap`
- returns user profile, roles, permissions, menu, dashboard cards, feature flags in one call

2. `mobile.get_active_visitors`
3. `mobile.get_pending_approvals`
4. `mobile.search_visitors`
5. `mobile.process_scan`
6. `mobile.submit_approval`

Keep existing APIs functional; mobile endpoints can aggregate and simplify payloads for speed.

---

## Non-Functional Requirements Checklist

- secure storage only for tokens/secrets
- no credentials in app code
- TLS required; cert pinning optional by env
- structured logging with PII-safe redaction
- crash reporting + API health metrics
- deterministic route guard tests
- repository + use-case unit tests
- golden tests for key operational screens
