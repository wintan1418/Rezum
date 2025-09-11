import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "cardElement", "submitButton", "errorElement"]
  static values = { 
    publishableKey: String, 
    clientSecret: String 
  }

  connect() {
    this.stripe = Stripe(this.publishableKeyValue)
    
    if (this.clientSecretValue) {
      this.confirmPayment()
    }
  }

  async confirmPayment() {
    if (!this.clientSecretValue) return
    
    try {
      const { error, paymentIntent } = await this.stripe.confirmPayment({
        clientSecret: this.clientSecretValue,
        confirmParams: {
          return_url: window.location.href
        }
      })

      if (error) {
        this.showError(error.message)
      } else if (paymentIntent.status === 'succeeded') {
        // Payment succeeded, redirect or show success message
        window.location.reload()
      }
    } catch (error) {
      this.showError('Payment confirmation failed. Please try again.')
    }
  }

  showError(message) {
    if (this.hasErrorElementTarget) {
      this.errorElementTarget.textContent = message
      this.errorElementTarget.classList.remove('hidden')
    } else {
      alert(message)
    }
  }

  hideError() {
    if (this.hasErrorElementTarget) {
      this.errorElementTarget.classList.add('hidden')
    }
  }
}
