# SkillBridge

**Connect. Work. Grow.**

SkillBridge connects skilled professionals with clients who need services, with admin verification, secure bookings, payments, chat, and moderation.

## Stack

- **Elixir** / **Phoenix 1.8** / **LiveView**
- **PostgreSQL** / **Ecto**
- **Tailwind CSS v4**
- Optional: **Stripe**, **Supabase Google OAuth**

## Setup

```bash
mix setup
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

## Demo accounts (after seeds)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@skillbridge.local | admin123 |
| User | hali.user@gmail.com | hali123 |
| Skilled | abaidullah@gmail.com | abaidullah123 |

Admin portal: `/admin/login` — also requires the platform admin key from seeds.

## Environment variables

See [.env.example](.env.example). In development:

- **Card (demo):** without `STRIPE_SECRET_KEY`, use test card `4242 4242 4242 4242` on the payment page (validates like Stripe test cards).
- **Card (live):** set `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, and `STRIPE_CURRENCY=pkr` for Stripe Checkout.
- **Bank / JazzCash / EasyPaisa:** pending until admin confirms under `/admin/payments`.
- Google sign-in appears on `/login` when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set.

## Main features

- Browse and book approved professionals
- Booking workflow: pending → confirmed → pay → complete
- Reviews and complaints with admin moderation
- Real-time chat and live location (privacy-offset)
- Platform fees and payment admin

## Tests

```bash
mix test
mix precommit   # compile, format, test
```
