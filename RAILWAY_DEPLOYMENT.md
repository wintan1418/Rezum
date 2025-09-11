# Railway Deployment Guide for Rezum

## Prerequisites
1. Railway account: https://railway.app
2. GitHub repository pushed with latest code
3. API keys for OpenAI, Anthropic, Google AI
4. Stripe account with live keys

## Step 1: Create Railway Project

1. Go to https://railway.app and sign in
2. Click "New Project" 
3. Select "Deploy from GitHub repo"
4. Choose your `rezum` repository
5. Railway will automatically detect it's a Rails app

## Step 2: Add Required Services

### Add PostgreSQL Database
1. In your Railway project, click "New Service"
2. Select "PostgreSQL" from the database options
3. Railway will provision a PostgreSQL instance and set `DATABASE_URL`

### Add Redis (for Sidekiq)
1. Click "New Service" again
2. Select "Redis" from the database options
3. Railway will provision Redis and set `REDIS_URL`

## Step 3: Configure Environment Variables

Go to your Rails service → Variables tab and add:

### Required Variables
```bash
RAILS_ENV=production
RAILS_MASTER_KEY=your_master_key_from_config_master_key
SECRET_KEY_BASE=generate_with_rails_secret

# AI Providers (at least one required)
OPENAI_API_KEY=sk-your_openai_key
ANTHROPIC_API_KEY=sk-ant-your_anthropic_key  
GOOGLE_AI_API_KEY=your_google_ai_key

# Stripe (use live keys for production)
STRIPE_PUBLISHABLE_KEY=pk_live_your_key
STRIPE_SECRET_KEY=sk_live_your_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

### Optional Variables
```bash
# OAuth (if using social login)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Email (if sending emails)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# App Config
APP_NAME=Rezum
ADMIN_EMAIL=admin@yourdomain.com
```

## Step 4: Get Your Keys

### Rails Master Key
```bash
# In your local project directory
cat config/master.key
```

### Generate Secret Key Base
```bash
# In your local project directory  
rails secret
```

### AI API Keys
- **OpenAI**: https://platform.openai.com/api-keys
- **Anthropic**: https://console.anthropic.com/
- **Google AI**: https://aistudio.google.com/app/apikey

### Stripe Keys
1. Go to https://dashboard.stripe.com/apikeys
2. Switch to "Live mode" (top right toggle)
3. Copy your live publishable and secret keys
4. For webhook secret: Webhooks → Add endpoint → Your Railway URL + `/webhooks/stripe`

## Step 5: Deploy

1. Push your code to GitHub (if not already done)
2. Railway will automatically detect changes and deploy
3. Monitor the build logs in Railway dashboard
4. Once deployed, you'll get a Railway URL like: `your-app.up.railway.app`

## Step 6: Run Database Migrations

In Railway dashboard:
1. Go to your Rails service
2. Click "Settings" → "Environment" 
3. Open the terminal/console
4. Run: `rails db:create db:migrate`

Or Railway should automatically run migrations via the Procfile.

## Step 7: Verify Deployment

Visit your Railway URL and verify:
- ✅ Homepage loads
- ✅ User registration/login works  
- ✅ Resume upload works
- ✅ AI optimization works
- ✅ Billing/Stripe integration works
- ✅ Background jobs processing (check Sidekiq at `/sidekiq`)

## Troubleshooting

### Common Issues

1. **Build fails**: Check Rails master key and secret key base are set
2. **Database errors**: Ensure PostgreSQL service is linked and `DATABASE_URL` is set
3. **Background jobs not working**: Ensure Redis service is linked and `REDIS_URL` is set  
4. **AI features not working**: Verify at least one AI API key is correctly set
5. **Stripe errors**: Ensure webhook endpoint is configured in Stripe dashboard

### Checking Logs
- Railway Dashboard → Your Service → Logs tab
- Monitor both build and runtime logs

### Environment Variables
- Ensure all required variables are set in Railway dashboard
- Double-check no typos in variable names
- Ensure no trailing spaces in values

## Scaling

### Enable Worker Processes
1. In Railway, you can scale your worker processes
2. The Procfile defines both web and worker processes
3. Railway will auto-scale based on traffic

### Monitoring
- Use Railway's built-in metrics
- Monitor Sidekiq at `/sidekiq` endpoint
- Set up error tracking (Sentry, etc.) if needed

## Cost Optimization

- Railway charges based on resource usage
- Monitor your usage in the dashboard
- Consider scaling down during low traffic periods
- Use Railway's sleep mode for staging environments