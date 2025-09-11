// Stimulus controller for country/phone selection with live updates
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "countrySelect", 
    "phoneInput", 
    "phoneCode", 
    "phoneExample",
    "currencyDisplay",
    "timezoneDisplay", 
    "vatInfo",
    "paymentMethods"
  ]
  
  static values = { 
    defaultCountry: String,
    autoDetect: Boolean 
  }

  connect() {
    this.updateCountryInfo()
    
    // Auto-detect user's country if enabled
    if (this.autoDetectValue) {
      this.detectUserCountry()
    }
  }

  // Called when country selection changes
  countryChanged() {
    this.updateCountryInfo()
    this.updatePhoneValidation()
    this.updateCurrencyDisplay()
    this.updateTimezoneInfo()
    this.updateVatInfo()
    this.updatePaymentMethods()
    
    // Dispatch event for other components
    this.dispatch("countryChanged", { 
      detail: { 
        countryCode: this.selectedCountryCode,
        countryData: this.getCountryData()
      } 
    })
  }

  // Update all country-related information
  updateCountryInfo() {
    const countryData = this.getCountryData()
    
    if (!countryData) return

    // Update phone code and placeholder
    if (this.hasPhoneCodeTarget) {
      this.phoneCodeTarget.textContent = countryData.phoneCode
    }
    
    if (this.hasPhoneExampleTarget) {
      this.phoneExampleTarget.textContent = `e.g., ${countryData.phoneExample}`
    }

    // Update phone input placeholder
    if (this.hasPhoneInputTarget) {
      this.phoneInputTarget.placeholder = countryData.phoneExample
      this.phoneInputTarget.setAttribute('data-country-code', countryData.code)
    }
  }

  // Update phone number validation
  updatePhoneValidation() {
    if (!this.hasPhoneInputTarget) return

    const countryData = this.getCountryData()
    if (!countryData) return

    // Remove previous validation classes
    this.phoneInputTarget.classList.remove('border-green-500', 'border-red-500')
    
    // Add real-time validation
    this.phoneInputTarget.addEventListener('input', () => {
      this.validatePhoneNumber()
    })
  }

  // Validate phone number format
  validatePhoneNumber() {
    if (!this.hasPhoneInputTarget) return

    const phoneValue = this.phoneInputTarget.value.trim()
    if (!phoneValue) {
      this.phoneInputTarget.classList.remove('border-green-500', 'border-red-500')
      return
    }

    // Simple validation - you might want to use a more sophisticated library
    const countryData = this.getCountryData()
    const phoneRegex = this.getPhoneRegexForCountry(countryData?.code)
    
    if (phoneRegex && phoneRegex.test(phoneValue)) {
      this.phoneInputTarget.classList.remove('border-red-500')
      this.phoneInputTarget.classList.add('border-green-500')
    } else {
      this.phoneInputTarget.classList.remove('border-green-500')
      this.phoneInputTarget.classList.add('border-red-500')
    }
  }

  // Update currency display
  updateCurrencyDisplay() {
    if (!this.hasCurrencyDisplayTarget) return

    const countryData = this.getCountryData()
    if (!countryData) return

    this.currencyDisplayTarget.innerHTML = `
      <span class="font-medium">${countryData.currencySymbol} ${countryData.currency}</span>
    `
  }

  // Update timezone information
  updateTimezoneInfo() {
    if (!this.hasTimezoneDisplayTarget) return

    const countryData = this.getCountryData()
    if (!countryData || !countryData.timezone) return

    // Calculate current time in selected timezone
    try {
      const now = new Date()
      const timeInZone = now.toLocaleTimeString('en-US', {
        timeZone: countryData.timezone,
        hour12: false,
        hour: '2-digit',
        minute: '2-digit'
      })
      
      const hour = parseInt(timeInZone.split(':')[0])
      const isBusinessHours = hour >= 9 && hour <= 17
      const icon = isBusinessHours ? '🟢' : '🌙'
      
      this.timezoneDisplayTarget.innerHTML = `
        <span class="flex items-center space-x-1">
          <span>${icon}</span>
          <span>${timeInZone}</span>
          <span class="text-sm text-gray-500">${countryData.timezone.split('/').pop().replace('_', ' ')}</span>
        </span>
      `
    } catch (e) {
      this.timezoneDisplayTarget.innerHTML = `
        <span class="text-gray-500">Timezone: ${countryData.timezone}</span>
      `
    }
  }

  // Update VAT/tax information
  updateVatInfo() {
    if (!this.hasVatInfoTarget) return

    const countryData = this.getCountryData()
    if (!countryData) return

    if (countryData.vatRate && parseFloat(countryData.vatRate) > 0) {
      this.vatInfoTarget.innerHTML = `
        <div class="text-sm text-yellow-600 bg-yellow-50 border border-yellow-200 rounded-md p-2">
          <strong>${countryData.vatDisplay}</strong> will be added at checkout
        </div>
      `
      this.vatInfoTarget.classList.remove('hidden')
    } else {
      this.vatInfoTarget.classList.add('hidden')
    }
  }

  // Update available payment methods
  updatePaymentMethods() {
    if (!this.hasPaymentMethodsTarget) return

    const countryData = this.getCountryData()
    if (!countryData || !countryData.paymentMethods) return

    const methods = countryData.paymentMethods.split(',')
    const methodsHtml = methods.map(method => {
      const icon = this.getPaymentMethodIcon(method)
      const name = this.getPaymentMethodName(method)
      
      return `
        <div class="flex items-center space-x-2 text-sm text-gray-600">
          <span>${icon}</span>
          <span>${name}</span>
        </div>
      `
    }).join('')

    this.paymentMethodsTarget.innerHTML = `
      <div class="space-y-1">
        <div class="text-sm font-medium text-gray-700">Available payment methods:</div>
        <div class="space-y-1">${methodsHtml}</div>
      </div>
    `
  }

  // Auto-detect user's country using various methods
  async detectUserCountry() {
    try {
      // Try to get country from browser/IP
      const response = await fetch('/api/detect-country', {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.country_code && this.hasCountrySelectTarget) {
          this.countrySelectTarget.value = data.country_code
          this.countryChanged()
        }
      }
    } catch (e) {
      console.log('Could not auto-detect country:', e)
    }
  }

  // Get selected country code
  get selectedCountryCode() {
    return this.hasCountrySelectTarget ? this.countrySelectTarget.value : this.defaultCountryValue
  }

  // Get country data from the select option
  getCountryData() {
    if (!this.hasCountrySelectTarget) return null

    const selectedOption = this.countrySelectTarget.selectedOptions[0]
    if (!selectedOption) return null

    return {
      code: selectedOption.value,
      name: selectedOption.textContent,
      currency: selectedOption.dataset.currency,
      currencySymbol: selectedOption.dataset.currencySymbol,
      phoneCode: selectedOption.dataset.phoneCode,
      phoneExample: selectedOption.dataset.phoneExample,
      timezone: selectedOption.dataset.timezone,
      vatRate: selectedOption.dataset.vatRate,
      vatDisplay: selectedOption.dataset.vatDisplay,
      languages: selectedOption.dataset.languages,
      paymentMethods: selectedOption.dataset.paymentMethods
    }
  }

  // Get phone regex for basic validation
  getPhoneRegexForCountry(countryCode) {
    const patterns = {
      'US': /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/,
      'CA': /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/,
      'GB': /^(\+44|0)[1-9]\d{8,9}$/,
      'DE': /^(\+49|0)[1-9]\d{6,11}$/,
      'FR': /^(\+33|0)[1-9]\d{8}$/,
      'ES': /^(\+34|0)[6-9]\d{8}$/,
      'IT': /^(\+39|0)[0-9]\d{6,10}$/,
      'NL': /^(\+31|0)[1-9]\d{8}$/,
      'AU': /^(\+61|0)[2-478]\d{8}$/
    }
    
    return patterns[countryCode] || /^\+?[1-9]\d{1,14}$/ // Basic international format
  }

  // Get payment method icon
  getPaymentMethodIcon(method) {
    const icons = {
      'stripe': '💳',
      'paypal': '🅿️',
      'mollie': '🏦',
      'apple_pay': '🍎',
      'google_pay': '🔍'
    }
    
    return icons[method] || '💳'
  }

  // Get payment method name
  getPaymentMethodName(method) {
    const names = {
      'stripe': 'Credit/Debit Card',
      'paypal': 'PayPal',
      'mollie': 'Bank Transfer',
      'apple_pay': 'Apple Pay',
      'google_pay': 'Google Pay'
    }
    
    return names[method] || method.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())
  }
}