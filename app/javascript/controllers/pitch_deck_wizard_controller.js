import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "prevBtn", "nextBtn", "submitBtn", "progressBar", "stepDot", "stepLabel"]

  connect() {
    this.currentStep = 0
    this.totalSteps = this.stepTargets.length
    this.updateUI()
  }

  nextStep() {
    if (this.currentStep < this.totalSteps - 1) {
      this.currentStep++
      this.updateUI()
    }
  }

  prevStep() {
    if (this.currentStep > 0) {
      this.currentStep--
      this.updateUI()
    }
  }

  goToStep(event) {
    const step = parseInt(event.currentTarget.dataset.step)
    if (step >= 0 && step < this.totalSteps) {
      this.currentStep = step
      this.updateUI()
    }
  }

  submit(event) {
    // Only allow submit on last step
    if (this.currentStep !== this.totalSteps - 1) {
      event.preventDefault()
    }
  }

  updateUI() {
    // Show/hide steps
    this.stepTargets.forEach((step, i) => {
      step.classList.toggle("hidden", i !== this.currentStep)
    })

    // Show/hide prev button
    if (this.hasPrevBtnTarget) {
      this.prevBtnTarget.classList.toggle("hidden", this.currentStep === 0)
    }

    // Show/hide next vs submit button
    const isLastStep = this.currentStep === this.totalSteps - 1
    if (this.hasNextBtnTarget) {
      this.nextBtnTarget.classList.toggle("hidden", isLastStep)
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.classList.toggle("hidden", !isLastStep)
    }

    // Update progress bar
    const progress = ((this.currentStep + 1) / this.totalSteps) * 100
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progress}%`
    }

    // Update step dots and labels
    this.stepDotTargets.forEach((dot, i) => {
      if (i <= this.currentStep) {
        dot.classList.add("border-purple-600", "bg-purple-600", "text-white")
        dot.classList.remove("border-gray-300")
      } else {
        dot.classList.remove("border-purple-600", "bg-purple-600", "text-white")
        dot.classList.add("border-gray-300")
      }
    })

    this.stepLabelTargets.forEach((label, i) => {
      label.classList.toggle("text-purple-600", i <= this.currentStep)
      label.classList.toggle("text-gray-400", i > this.currentStep)
    })

    // Scroll to top of form
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
