import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlInput", "fetchButton", "buttonText", "spinner", "jobDescription",
                     "successMessage", "errorMessage", "fetchedInfo", "errorText"]

  async fetchJob() {
    const url = this.urlInputTarget.value.trim()

    if (!url) {
      this.showError("Please enter a valid job posting URL")
      return
    }

    if (!this.isValidUrl(url)) {
      this.showError("Please enter a valid URL (must start with http:// or https://)")
      return
    }

    this.setLoading(true)
    this.hideMessages()

    try {
      const response = await fetch("/api/fetch-job-posting", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ url: url })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.handleSuccess(data)
      } else {
        this.showError(data.error || "Failed to fetch job posting")
      }
    } catch (error) {
      console.error("Error fetching job:", error)
      this.showError("Network error. Please check your connection and try again.")
    } finally {
      this.setLoading(false)
    }
  }

  handleSuccess(data) {
    this.jobDescriptionTarget.value = data.job_description

    let infoText = ""
    if (data.company_name) infoText += `Company: ${data.company_name} `
    if (data.job_title) infoText += `• Role: ${data.job_title} `
    if (data.location) infoText += `• Location: ${data.location}`

    this.fetchedInfoTarget.textContent = infoText || "Job posting content extracted successfully"
    this.successMessageTarget.classList.remove("hidden")

    if (data.job_title) {
      const targetRoleInput = document.querySelector("#resume_target_role")
      if (targetRoleInput && !targetRoleInput.value) {
        targetRoleInput.value = data.job_title
      }
    }

    this.jobDescriptionTarget.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  showError(message) {
    this.errorTextTarget.textContent = message
    this.errorMessageTarget.classList.remove("hidden")
  }

  hideMessages() {
    this.successMessageTarget.classList.add("hidden")
    this.errorMessageTarget.classList.add("hidden")
  }

  setLoading(loading) {
    if (loading) {
      this.buttonTextTarget.textContent = "Fetching..."
      this.spinnerTarget.classList.remove("hidden")
      this.fetchButtonTarget.disabled = true
    } else {
      this.buttonTextTarget.textContent = "Fetch"
      this.spinnerTarget.classList.add("hidden")
      this.fetchButtonTarget.disabled = false
    }
  }

  isValidUrl(string) {
    try {
      new URL(string)
      return string.startsWith("http://") || string.startsWith("https://")
    } catch (_) {
      return false
    }
  }
}
