# MakeWebsite.io Project Report

Generated: May 23, 2026

## 1. Executive Summary

MakeWebsite.io is a multi-tenant ecommerce SaaS platform. It lets users create online boutiques, manage products, receive public storefront orders, track customers and traffic, manage team members, handle subscriptions, and configure payments, branding, delivery, notifications, and store settings.

The project is split into:

- `backend/`: Java Spring Boot REST API
- `frontend/`: Flutter application targeting web and Android
- `uploads/`: uploaded images and store media
- `nginx.conf`: reverse proxy for serving frontend and backend under one domain
- `schema.sql` and Flyway migrations: database schema history

## 2. Technology Stack

| Layer | Technology |
|---|---|
| Backend | Spring Boot 3.2.4 |
| Backend language | Java 17 |
| Backend build tool | Maven |
| API style | REST JSON |
| ORM | Spring Data JPA / Hibernate |
| Security | Spring Security, JWT |
| JWT library | jjwt 0.12.3 |
| Database | PostgreSQL |
| Migrations | Flyway |
| Email | Spring Mail / Gmail SMTP |
| Payments | Stripe Java SDK |
| Realtime | Spring WebSocket / STOMP |
| Frontend | Flutter / Dart |
| Frontend routing | go_router |
| Frontend state | Provider / ChangeNotifier |
| Frontend HTTP | Dio |
| Maps | flutter_map, latlong2 |
| Charts | fl_chart |
| Proxy/deployment helper | nginx |

## 3. Main Product Capabilities

### Store owner features

- Register, login, reset password, verify email, and manage profile.
- Create and manage multiple boutiques.
- Configure store branding, countries, currency, delivery settings, notification settings, custom code, social links, SEO, and theme.
- Publish or unpublish public storefronts.
- Manage products, variants, inventory, featured products, stock, and bulk imports.
- Manage categories.
- Manage orders, order statuses, payment statuses, tracking, refunds, and invoices.
- Manage customers and export customer data.
- Manage coupons and validate discounts.
- View analytics, revenue charts, top products, and traffic sources.
- Track traffic, visitors, sessions, map data, and live visitor activity.
- Manage reviews, approve/reject reviews, reply to reviews.
- Use POS/caisse features: sessions, transactions, cashier management.
- Manage team members and invitations.
- Use AI assistant and public chat features.
- Configure Telegram-related store settings.
- Manage notifications and messages.

### Public customer features

- Browse public stores by slug.
- View store products and categories.
- View product details.
- Add products to cart.
- Checkout and place public orders.
- Submit product reviews.
- Send public chat/contact messages.
- Track successful order flow.

### Platform/admin features

- Admin dashboard.
- Super admin dashboard.
- User management.
- Store management.
- Subscription management.
- Audit/activity logs.
- Store freeze/unfreeze controls.
- CSV export endpoints for admin data.

## 4. Repository Structure

```text
web/
  backend/
    pom.xml
    src/main/java/io/makewebsite/
      MakeWebsiteApplication.java
      config/
      controller/
      dto/
      entity/
      exception/
      repository/
      security/
      service/
      util/
    src/main/resources/
      application.properties
      schema.sql
      db/migration/
  frontend/
    pubspec.yaml
    lib/
      main.dart
      core/
      models/
      providers/
      screens/
      services/
      theme/
      widgets/
    android/
    web/
    test/
  uploads/
  nginx.conf
  schema.sql
  static_server.js
  spa_server.py
  PROJECT_REPORT.md
```

## 5. Backend Architecture

The backend follows a standard Spring Boot layered architecture:

- Controllers receive HTTP requests under `/api/...`.
- Services contain business logic.
- Repositories access PostgreSQL through Spring Data JPA.
- Entities map database tables.
- DTOs define request and response payloads.
- Security classes handle JWT auth, tenant context, and permissions.
- Flyway migrations manage database changes.

Important backend packages:

| Package | Purpose |
|---|---|
| `controller` | REST endpoints |
| `service` | Business logic |
| `repository` | Database access |
| `entity` | JPA table mappings |
| `dto/request` | Incoming API payloads |
| `dto/response` | Outgoing API payloads |
| `security` | JWT, tenant, user principal, permissions |
| `config` | Security, CORS, WebSocket, MVC, filters |
| `exception` | Centralized API error handling |

## 6. Frontend Architecture

The frontend is a Flutter app using:

- `MaterialApp.router` with `go_router`
- `Provider` for state management
- `Dio` for API calls
- Shared model classes in `lib/models`
- Shared UI widgets in `lib/widgets`
- Feature screens grouped under `lib/screens`

Important frontend files:

| File | Purpose |
|---|---|
| `frontend/lib/main.dart` | App entry point, providers, localization, router setup |
| `frontend/lib/core/router.dart` | Route definitions and redirects |
| `frontend/lib/core/api_client.dart` | Dio client and API request handling |
| `frontend/lib/core/env_config.dart` | Build-time environment configuration |
| `frontend/lib/core/storage.dart` | Local token/session storage |
| `frontend/lib/widgets/main_scaffold.dart` | Main authenticated layout |
| `frontend/lib/theme/app_theme.dart` | App theme |

## 7. Main Frontend Routes

Public routes:

| Route | Purpose |
|---|---|
| `/landing` | Landing page |
| `/login` | Login |
| `/register` and `/signup` | Registration |
| `/forgot-password` | Password reset request |
| `/reset-password` | Password reset form |
| `/verify-email` | Email verification screen |
| `/store/:slug` | Public storefront |
| `/store/:slug/product/:productId` | Public product detail |
| `/store/:slug/cart` | Public cart |
| `/store/:slug/checkout` | Public checkout |
| `/store/:slug/order-success/:orderId` | Public order success |
| `/public-store/:slug` | Alternate public storefront route |
| `/explore` | Public store browser |
| `/create-store` | Store creation |
| `/store-selector` | Select active store |

Authenticated/admin routes include:

- `/home`
- `/products`
- `/products/add`
- `/products/edit/:id`
- `/products/bulk-add`
- `/orders`
- `/orders/:id`
- `/customers`
- `/customers/:id`
- `/analytics`
- `/traffic`
- `/traffic/analytics`
- `/pos`
- `/pos/admin`
- `/inventory`
- `/delivery`
- `/messages`
- `/team`
- `/reviews`
- `/coupons`
- `/notifications`
- `/profile`
- `/subscription`
- `/boutique-settings`
- `/ai-assistant`
- `/admin`
- `/admin/activities`
- `/super-admin`

## 8. Main API Areas

Important backend API prefixes:

| Prefix | Purpose |
|---|---|
| `/api/auth` | Register, login, refresh, profile, password reset, logout |
| `/api/users` | Current user, profile picture, password, active boutique |
| `/api/boutiques` | Boutique CRUD, dashboard, settings, publish/unpublish |
| `/api/boutiques/{id}` | Detailed store settings, media, countries, language |
| `/api/products` | Product CRUD, stock, featured/active toggles, export, bulk import |
| `/api/products/{productId}/variants` | Product variants |
| `/api/categories` | Category CRUD |
| `/api/orders` | Orders, order status, payment status, tracking, refunds, invoices |
| `/api/customers` | Customer CRUD and export |
| `/api/coupons` | Coupon CRUD and validation |
| `/api/cart` | Authenticated cart |
| `/api/public` | Public store, products, orders, chat, subscribe, visits |
| `/api/analytics` | Revenue, top products, traffic sources |
| `/api/traffic` | Traffic stats, visitors, sessions, live data, export |
| `/api/messages` | Public messages and owner replies |
| `/api/notifications` | Notifications and read/delete actions |
| `/api/reviews` | Store review moderation |
| `/api/products/{productId}/reviews` | Public product reviews |
| `/api/team` | Team members and invitations |
| `/api/pos` | POS sessions and transactions |
| `/api/payments` | Stripe payment intents, checkout, webhooks |
| `/api/super-admin` | Platform-level admin tools |
| `/api/admin` | Admin overview, users, boutiques, stats |
| `/api/upload` | Image upload |
| `/api/security` | User sessions and account deletion |

## 9. Database

The app uses PostgreSQL with Flyway migrations.

Default database settings from `backend/src/main/resources/application.properties`:

```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/makewebsite_db
spring.datasource.username=postgres
spring.datasource.password=postgres
spring.jpa.hibernate.ddl-auto=validate
spring.flyway.enabled=true
spring.flyway.baseline-on-migrate=true
```

Current migration files include `V2` through `V28`.

Key schema areas:

- Users and sessions
- Tenants
- Boutiques/stores
- Store settings and media
- Products and variants
- Categories
- Carts
- Orders and invoices
- Customers
- Coupons
- Reviews
- Messages/conversations
- Notifications
- Team members and invitations
- Subscriptions/plans
- POS sessions and transactions
- Traffic sessions, visitors, and store views
- Admin audit/activity logs

## 10. Configuration

### Backend environment variables

Use these environment variables for local or production configuration:

| Variable | Purpose |
|---|---|
| `JWT_SECRET` | Required for secure JWT signing |
| `GMAIL_APP_PASSWORD` | Gmail SMTP app password |
| `APP_PUBLIC_URL` | Public backend URL, used for uploads and generated links |
| `APP_FRONTEND_URL` | Public frontend URL, used for redirects |
| `STRIPE_SECRET_KEY` | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `ANTHROPIC_API_KEY` | Anthropic API key |

The file currently has placeholder values for OpenAI and Telegram:

```properties
openai.api-key=YOUR_OPENAI_API_KEY
telegram.bot-token=YOUR_TELEGRAM_BOT_TOKEN
```

For production, these should also be moved to environment variables.

### Frontend build variables

`frontend/lib/core/env_config.dart` supports:

| Dart define | Purpose |
|---|---|
| `ENV` | Environment label |
| `API_BASE_URL` | Backend API base URL |
| `WS_URL` | WebSocket URL |
| `FRONTEND_PUBLIC_URL` | Public frontend URL |

Example:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

For Android emulator, the default API URL is:

```text
http://10.0.2.2:8080/api
```

For Flutter web local development, you usually want:

```text
http://localhost:8080/api
```

## 11. How To Run Locally

### Prerequisites

Install:

- Java 17
- Maven
- PostgreSQL
- Flutter SDK
- Chrome or Edge for Flutter web

### Start PostgreSQL

Create the database if needed:

```sql
CREATE DATABASE makewebsite_db;
```

Default local credentials expected by the app:

```text
database: makewebsite_db
username: postgres
password: postgres
host: localhost
port: 5432
```

### Start backend

From the project root:

```powershell
cd backend
mvn spring-boot:run
```

Expected backend URL:

```text
http://localhost:8080
```

### Start frontend web

From the project root:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api --dart-define=WS_URL=http://localhost:8080/ws --dart-define=FRONTEND_PUBLIC_URL=http://localhost:8080
```

Flutter will print the local frontend URL.

### Build frontend web

```powershell
cd frontend
flutter build web --release --dart-define=API_BASE_URL=/api --dart-define=WS_URL=/ws
```

Then serve `frontend/build/web` with a static server or nginx.

## 12. Nginx Proxy

`nginx.conf` is configured to:

- Send frontend routes to Flutter dev server on port `52606`.
- Send `/api/` to Spring Boot on port `8080`.
- Send `/uploads/` to Spring Boot uploads on port `8080`.

This is useful when exposing the app through one public domain or ngrok URL.

Current proxy targets:

| Path | Target |
|---|---|
| `/` | `http://localhost:52606` |
| `/api/` | `http://localhost:8080/api/` |
| `/uploads/` | `http://localhost:8080/uploads/` |

If your Flutter dev server runs on a different port, update `nginx.conf`.

## 13. Security Model

The app uses:

- JWT access tokens and refresh tokens.
- Spring Security filters.
- Tenant context for multi-tenant data isolation.
- Role and permission classes.
- Session management endpoints.
- CORS configuration for localhost and ngrok domains.

Important files:

- `backend/src/main/java/io/makewebsite/config/SecurityConfig.java`
- `backend/src/main/java/io/makewebsite/security/JwtAuthFilter.java`
- `backend/src/main/java/io/makewebsite/security/JwtUtil.java`
- `backend/src/main/java/io/makewebsite/security/TenantContext.java`
- `backend/src/main/java/io/makewebsite/security/RolePermissions.java`

Production security notes:

- Set a strong `JWT_SECRET`.
- Do not keep real secrets in `application.properties`.
- Disable mail debug logging in production.
- Review CORS origins before production.
- Use HTTPS.
- Protect Stripe webhooks with `STRIPE_WEBHOOK_SECRET`.

## 14. Known Useful Commands

Compile backend:

```powershell
cd backend
mvn -DskipTests compile
```

Run backend:

```powershell
cd backend
mvn spring-boot:run
```

Get Flutter dependencies:

```powershell
cd frontend
flutter pub get
```

Analyze Flutter code:

```powershell
cd frontend
flutter analyze
```

Run Flutter web:

```powershell
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

Build Flutter web:

```powershell
cd frontend
flutter build web --release --dart-define=API_BASE_URL=/api
```

## 15. Current Git/Workspace Notes

At the time this report was generated, the workspace had local changes in:

- `frontend/android/app/src/main/AndroidManifest.xml`
- `frontend/lib/core/env_config.dart`
- `frontend/lib/main.dart`
- `frontend/lib/screens/public_storefront/public_storefront_screen.dart`
- `frontend/lib/widgets/main_scaffold.dart`

And untracked files:

- `PROJECT_REPORT.md`
- `frontend/lib/services/web_utils.dart`
- `frontend/lib/services/web_utils_stub.dart`
- `frontend/lib/services/web_utils_web.dart`

Review these before committing.

## 16. Practical Next Steps

To use the project locally:

1. Start PostgreSQL and make sure `makewebsite_db` exists.
2. Set required environment variables, especially `JWT_SECRET` and `GMAIL_APP_PASSWORD`.
3. Run the backend with Maven.
4. Run the Flutter frontend with `API_BASE_URL=http://localhost:8080/api`.
5. Register a user, create a store, add products, publish the store, then visit `/store/{slug}`.

To prepare for production:

1. Move all secrets to environment variables.
2. Use a production PostgreSQL database.
3. Serve the Flutter web build through nginx.
4. Put backend and frontend behind HTTPS.
5. Configure Stripe live keys and webhooks.
6. Configure production email.
7. Lock CORS to real production domains.
8. Run backend compile/tests and `flutter analyze`.

