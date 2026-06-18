# MakeWebsite.io

**SaaS e-commerce platform** — Create, manage and grow your online store with a customizable storefront, AI-powered assistant, POS system, and comprehensive analytics.

Built with **Flutter** (web + Android mobile) and **Spring Boot** (REST API + PostgreSQL).

---

## Features

- **Store Management** — Create and customize online stores (domain, logo, colors, SEO, CSS)
- **Multi-Store** — Own and manage multiple boutiques from a single dashboard
- **Product Management** — CRUD, variants (color/size/price), categories, bulk import, inventory
- **Order Management** — Full lifecycle (pending → confirmed → shipped → delivered), tracking, invoices
- **Customer Management** — CRM with order history, notes, and contact info
- **Point of Sale (POS)** — In-person sales with cash register sessions and transaction tracking
- **Customer Reviews** — Product ratings (1–5), merchant replies, moderation workflow
- **AI Assistant** — Local Ollama-powered chatbot that answers questions about your store data
- **Shopping Cart & Wishlist** — Authenticated and guest cart support
- **Checkout & Payments** — COD, Stripe
- **Coupon & Discount System** — Promotional codes with configurable rules
- **Team Management** — Role-based access (OWNER, ADMIN, MANAGER) with granular permissions
- **Analytics & Traffic** — Store visits, geolocation, browser/device tracking, session analytics
- **Notifications** — In-app + Telegram bot integration
- **Messaging** — Customer conversation system with WebSocket live updates
- **Delivery Zones** — Configure shipping zones and rates per store
- **Super Admin Dashboard** — Platform-level management and audit logs
- **Subscription Plans** — Free trial (3 days), 3-month (99 DT), Premium (35 DT/month)
---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.2+ (Dart) — web & Android mobile |
| Backend | Java 17, Spring Boot 3.2.4 |
| Database | PostgreSQL + Flyway migrations |
| Auth | JWT (access + refresh tokens), BCrypt |
| AI | Ollama (`qwen3:8b`, fallback `llama3.1:8b`) |
| Payments | Stripe, COD |
| Real-time | WebSocket (STOMP) |
| Proxy | nginx |

### Frontend Dependencies

Dio (HTTP), Provider (state), GoRouter (routing), fl_chart, flutter_map, stomp_dart_client, image_picker, google_fonts, flutter_quill, cached_network_image, shimmer, skeletonizer, share_plus.

### Backend Dependencies

Spring Boot (Web, JPA, Security, Validation, Mail), Lombok, Jackson, Flyway, jjwt, Stripe SDK.

---

## Architecture

```
nginx (port 80)
├── / → Flutter web SPA (proxied :52606)
├── /api/* → Spring Boot backend (:8080)
└── /uploads/* → Static file server (:8080)

Spring Boot Backend (:8080)
├── Security Layer
│   ├── JwtAuthFilter
│   ├── StoreSlugFilter
│   └── VisitorTrackingFilter
├── REST Controllers (30+)
├── Services (business logic)
├── Repositories (Spring Data JPA)
├── Entities (35+ JPA entities)
└── PostgreSQL + Flyway

Flutter Frontend
├── Screens (30+)
├── Providers (state management, 16 providers)
├── Core Services (ApiClient, Router, WebSocket, Traffic)
└── Widgets (reusable components)
```

---

## Getting Started

### Prerequisites

- Java 17+
- Maven
- Flutter 3.2+
- PostgreSQL
- nginx (for production)

### Environment Variables

| Variable | Description |
|----------|-------------|
| `JWT_SECRET` | JWT signing secret |
| `STRIPE_SECRET_KEY` | Stripe API secret key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `GMAIL_APP_PASSWORD` | Gmail app password for SMTP |
| `APP_PUBLIC_URL` | Backend public URL (`http://localhost:8080`) |
| `APP_FRONTEND_URL` | Frontend URL for CORS |

### Database

```bash
createdb makewebsite_db
# Schema is managed automatically via Flyway migrations
```

### Backend

```bash
cd backend
mvn spring-boot:run
```

Runs on `http://localhost:8080`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome    # web
flutter run -d android   # mobile
```

The Flutter dev server runs on port `52606` by default.

### AI Assistant (Ollama)

```bash
ollama pull qwen3:8b
ollama pull llama3.1:8b
ollama serve
```

Configured in `application.properties`:
```properties
ollama.base-url=http://localhost:11434
ollama.model=qwen3:8b
ollama.fallback-model=llama3.1:8b
```

### Production (nginx)

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:52606;
    }

    location /api/ {
        proxy_pass http://localhost:8080/api/;
    }

    location /uploads/ {
        proxy_pass http://localhost:8080/uploads/;
    }
}
```

---

## Project Structure

```
├── backend/
│   └── src/main/java/io/makewebsite/
│       ├── config/          # Security, CORS, app config
│       ├── controller/      # REST endpoints
│       ├── dto/             # Request/response DTOs
│       ├── entity/          # JPA entities
│       ├── repository/      # Spring Data repositories
│       ├── security/        # JWT auth, user principal
│       └── service/         # Business logic
│   └── src/main/resources/
│       ├── db/migration/    # Flyway migrations
│       └── application.properties
├── frontend/
│   └── lib/
│       ├── core/            # ApiClient, Router, env config
│       ├── models/          # Data models
│       ├── providers/       # State management
│       ├── screens/         # UI screens (30+)
│       ├── services/        # WebSocket, CSV export, etc.
│       ├── theme/           # Colors, typography
│       └── widgets/         # Reusable components
└── uploads/                 # File storage (gitignored)
```

---

## License

Private — all rights reserved.
