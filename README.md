# Rezum

Rezum is a Ruby on Rails SaaS app for job seekers. It helps users create and improve job-search assets with AI, manage applications, and pay through credits or subscriptions.

## Core Features

- AI resume optimization with ATS keyword extraction and scoring
- Resume builder and resume wizard with PDF, DOCX, and text downloads
- AI cover letter generation and variations
- Public free ATS checker lead magnet
- Job application tracker
- Premium interview prep, LinkedIn optimization, and job scraping
- AI pitch deck generation and PPTX export
- Paystack billing for credit packs and subscriptions
- Admin dashboard for users, leads, articles, hire messages, marketing, and conversations
- Blog/content hub, referrals, onboarding, and email drip campaigns

## Stack

- Ruby on Rails 7.2
- PostgreSQL
- Redis and Sidekiq
- Devise authentication with Google OAuth
- Turbo, Stimulus, Tailwind CSS, and esbuild
- Active Storage
- OpenAI/RubyLLM AI integrations
- Paystack payments

## Requirements

- Ruby version from `.ruby-version`
- Node version from `.node-version`
- PostgreSQL
- Redis
- Yarn

## Setup

```bash
bundle install
yarn install
bin/rails db:create db:migrate db:seed
```

Start the app locally:

```bash
bin/dev
```

Run Sidekiq separately if your local Procfile does not start it:

```bash
bundle exec sidekiq
```

## Environment Variables

Create `.env` from `.env.example` and configure the values needed for your environment.

Important payment variables:

```bash
PAYSTACK_PUBLIC_KEY=
PAYSTACK_SECRET_KEY=
PAYSTACK_PLAN_MONTHLY_PRO=
PAYSTACK_PLAN_ANNUAL_PRO=
PAYSTACK_PLAN_MONTHLY_PREMIUM=
PAYSTACK_PLAN_ANNUAL_PREMIUM=
```

Important AI variables:

```bash
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=
OPENAI_PRIMARY_MODEL=gpt-4o
OPENAI_FAST_MODEL=gpt-4o-mini
ANTHROPIC_PRIMARY_MODEL=claude-3-5-sonnet-latest
GOOGLE_PRIMARY_MODEL=gemini-2.0-flash
```

Model names are environment-configurable so production can be updated without code changes.

## Paystack Billing Notes

Paystack is the payment provider for both Nigerian and international users.

For Nigerian users, the app displays and charges NGN.

For users outside Nigeria, the app may show USD prices as user-friendly estimates, but Paystack processes the equivalent NGN amount and the cardholder's bank handles conversion. Keep this disclosed anywhere pricing is shown so users are not surprised by the settlement currency.

## Credits

Credit costs are centralized in `CreditPolicy`:

- Cover letter: 1 credit
- Resume optimization: 2 credits
- ATS score: 2 credits
- LinkedIn optimization: 2 credits
- Interview prep: 3 credits
- Resume wizard unlock: 10 credits
- Pitch deck: 30 credits

Use `current_user.can_generate?(cost)` before starting work and `current_user.deduct_credits!(cost)` after successful generation. Do not directly decrement `credits_remaining`.

## Tests

Run the full test suite:

```bash
bin/rails test
```

Run security scanning:

```bash
bundle exec brakeman --no-pager
```

Run autoload verification:

```bash
bin/rails zeitwerk:check
```

## Security Notes

- User-owned resources should always be loaded through `current_user`.
- `/sidekiq` is admin-only and requires Redis when accessed.
- Paystack webhooks verify the `X-Paystack-Signature` header.
- Keep AI provider credentials and Paystack secret keys out of git.

## Deployment Checklist

- PostgreSQL database is migrated.
- Redis is available for Sidekiq.
- Paystack keys and plan codes are configured.
- AI provider keys and model env vars are configured.
- Active Storage service is configured for production.
- SMTP settings are configured for Devise and product emails.
- `SECRET_KEY_BASE` is set.
- Background workers are running.
- `/up` health check is reachable.
