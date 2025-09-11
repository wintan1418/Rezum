#!/bin/bash

echo "🚀 Setting up Stripe Integration for Rezum"
echo "=========================================="

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env << 'ENVEOF'
# Stripe Configuration (Test Mode)
STRIPE_PUBLISHABLE_KEY=pk_test_51234567890abcdefghijklmnopqrstuvwxyz
STRIPE_SECRET_KEY=sk_test_51234567890abcdefghijklmnopqrstuvwxyz
STRIPE_WEBHOOK_SECRET=whsec_1234567890abcdefghijklmnopqrstuvwxyz

# Note: Replace these with your actual Stripe test keys from:
# https://dashboard.stripe.com/test/apikeys
ENVEOF
    echo "✅ Created .env file with placeholder keys"
else
    echo "⚠️  .env file already exists"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Go to https://dashboard.stripe.com/test/apikeys"
echo "2. Copy your test API keys"
echo "3. Replace the placeholder keys in .env file"
echo "4. Create products in Stripe Dashboard:"
echo "   - Monthly Pro: $29/month"
echo "   - Annual Pro: $290/year"
echo "5. Update price IDs in app/controllers/subscriptions_controller.rb"
echo ""
echo "🧪 Test with these card numbers:"
echo "   Success: 4242424242424242"
echo "   3D Secure: 4000002500003155"
echo "   Decline: 4000000000000002"
echo ""
echo "🔧 To start the server:"
echo "   rails server"
echo ""
echo "🌐 Then visit: http://localhost:3000/billing"
