import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="newsletter"
export default class extends Controller {
  static targets = ["email", "form", "success", "button"]

  subscribe() {
    const email = this.emailTarget.value.trim()
    
    // Basic email validation
    if (!email || !this.isValidEmail(email)) {
      this.emailTarget.classList.add('border-red-500', 'ring-2', 'ring-red-500')
      this.emailTarget.focus()
      
      setTimeout(() => {
        this.emailTarget.classList.remove('border-red-500', 'ring-2', 'ring-red-500')
      }, 2000)
      return
    }

    // Show loading state
    this.buttonTarget.disabled = true
    this.buttonTarget.innerHTML = `
      <svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    `

    // Simulate API call (replace with real API when backend is ready)
    setTimeout(() => {
      // Store email in localStorage to remember subscription
      localStorage.setItem('newsletter_subscribed', 'true')
      localStorage.setItem('newsletter_email', email)
      
      // Hide form, show success
      this.formTarget.classList.add('hidden')
      this.successTarget.classList.remove('hidden')
    }, 800)
  }

  isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }

  connect() {
    // Check if already subscribed
    if (localStorage.getItem('newsletter_subscribed') === 'true') {
      this.formTarget.classList.add('hidden')
      this.successTarget.classList.remove('hidden')
    }
  }
}
