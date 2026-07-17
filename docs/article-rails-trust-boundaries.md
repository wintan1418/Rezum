# What Shipping an AI Product in Rails Taught Me About Trust Boundaries

I spent the last few months building RezumFit, a Rails SaaS that optimizes resumes with AI. Somewhere between the third payment bug and the first hallucinated resume metric, I stopped thinking of it as an AI product and started thinking of it as a trust problem with a Ruby codebase attached. Here are the principles that ended up mattering, with the technical details, because the details are where the work actually lives.

## 1. Never let a model do a calculator's job

Our ATS score used to come from asking GPT to "rate this resume against this job description." Same resume, same job, three different scores on three runs. Users noticed, and they were right to.

The fix was embarrassingly boring. I wrote a plain Ruby service that extracts keywords from the job description once, then matches them against the resume with word boundary regexes that survive terms like C++ and .NET, weighted so a required hard skill counts three times more than a soft skill. The match rate is now arithmetic. It is the same number every single time, and I can show the user exactly which keywords hit and which are missing.

The model still writes the qualitative analysis, but the prompt receives the computed match data labeled as ground truth and is told not to recount anything. LLMs are excellent at language and unreliable at counting. Architect accordingly: deterministic Ruby for anything a user might compare across runs, generative AI only for what genuinely requires generation.

## 2. Verify generated output against its source, in code

Every AI resume tool on the market has the same failure mode: the model invents a metric. "Increased revenue by 250%" appears in a resume whose source material never mentioned revenue. No vendor guards against this. They just tell you to proofread.

So we built the guard as a pipeline stage. After generation, a second, cheaper model call runs at temperature zero with one job: compare the generated document to the source and return JSON listing every claim the source does not support. If the list is non-empty, a targeted revision pass removes only those claims and leaves everything else untouched.

Two design decisions made this production-safe. First, the guard fails open: if the verification call itself errors, we log it and ship the unverified content, because a safety net that can take down the feature it protects is worse than no net. Second, verification runs on the mini model and revision only fires when needed, so the median cost is one cheap call.

## 3. The signed webhook is the only source of truth for money

We take payments through Paystack. Like most gateways, it gives you two signals: a browser redirect back to your site with a transaction reference, and a signed webhook. The redirect is a URL any user can construct. The webhook is HMAC-SHA512 over the raw body, compared in constant time.

Our redirect handler originally did too much. It would verify the reference, then fill in gaps: default the plan, fabricate a subscription code. That is access control built on guesswork. Now the redirect path activates a subscription only when everything checks out server side, including that the transaction's customer email matches the signed-in user, because references leak and replay is cheap. Anything incomplete gets a friendly "payment received, activating shortly" and waits for the webhook, which is idempotent, guarded by a "have we already credited this?" check, since gateways love sending the same event twice.

The same discipline applies to credits. Deduction happens inside `with_lock` with a double-checked balance, because two concurrent generation requests will absolutely race each other on a Friday night.

## 4. The request cycle is sacred

Our free ATS checker, the top of the whole funnel, used to call OpenAI synchronously inside the controller action. Fifteen seconds of a Puma thread held hostage per check. Under real traffic, that is how a lead magnet becomes an outage.

The rework is classic Rails: the controller extracts text from the upload (fast, local), enqueues a Sidekiq job with a random token, and returns immediately with a Turbo Stream. The job stores the scored result in Redis with a TTL, and a 25-line Stimulus controller polls a result endpoint that returns 204 until the payload exists, then swaps itself out. No websockets ceremony for a fire-and-forget flow, no thread held longer than the file parse. If a web request waits on a third party, it is a bug with good manners.

## 5. Treat every outbound URL as hostile

We have a feature that fetches a job posting from a pasted URL. Server-side fetching of user-supplied URLs is SSRF on a silver platter, especially on a host with a private network attached. The guard resolves DNS and rejects anything private, loopback, or link local, allows only ports 80 and 443, refuses URLs with embedded credentials, and, critically, re-validates every redirect hop, because a public URL that 302s to an internal address is the classic bypass.

## The thread through all of it

None of this is exotic. It is service objects, Sidekiq, row locks, HMAC checks, and regexes, which is to say it is Rails, applied with a clear map of where trust boundaries sit: between you and the model, you and the gateway, you and the user's browser, you and the URLs they paste. AI made the product possible. Knowing exactly what not to trust made it shippable.
