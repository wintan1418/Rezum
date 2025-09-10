// Country Detection controller for auto-detecting user's location
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    apiUrl: String 
  }

  connect() {
    // Auto-detect country when page loads
    this.detectCountry()
  }

  async detectCountry() {
    try {
      // Don't detect if we're on localhost/development to avoid API calls
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log('Development environment - skipping country detection')
        return
      }

      const response = await fetch(this.apiUrlValue, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // Dispatch country detected event that other controllers can listen to
        this.dispatch("countryDetected", { 
          detail: { 
            countryCode: data.country_code,
            countryName: data.country_name,
            countryFlag: data.country_flag,
            currency: data.currency,
            language: data.language,
            timezone: data.timezone,
            phoneCode: data.phone_code,
            vatRate: data.vat_rate,
            paymentMethods: data.payment_methods,
            detectedFrom: data.detected_from
          } 
        })

        console.log('Country detected:', data)
      }
    } catch (error) {
      console.log('Could not detect country:', error)
      
      // Fallback to browser language detection
      this.detectFromBrowser()
    }
  }

  detectFromBrowser() {
    try {
      // Get browser language
      const browserLang = navigator.language || navigator.userLanguage
      const langCode = browserLang.split('-')[0]
      
      // Simple mapping of languages to likely countries
      const langToCountry = {
        'en': 'US',
        'es': 'ES', 
        'fr': 'FR',
        'de': 'DE',
        'it': 'IT',
        'pt': 'BR',
        'nl': 'NL',
        'ja': 'JP',
        'ko': 'KR'
      }
      
      const likelyCountry = langToCountry[langCode] || 'US'
      
      // Dispatch browser-detected country
      this.dispatch("countryDetected", { 
        detail: { 
          countryCode: likelyCountry,
          detectedFrom: 'browser_language'
        } 
      })
      
      console.log('Country detected from browser language:', likelyCountry)
    } catch (error) {
      console.log('Browser detection failed:', error)
    }
  }
}