import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typewriter", "statusText", "subText", "timer", "step"]

  connect() {
    console.log("Generation animation controller connected")
    this.currentStep = 1
    this.startTime = Date.now()
    this.animationPhase = 0
    
    this.startAnimationSequence()
    this.startTimer()
  }

  disconnect() {
    this.stopAnimations()
  }

  startAnimationSequence() {
    // Phase rotation every 8 seconds
    this.animationInterval = setInterval(() => {
      this.nextAnimationPhase()
    }, 8000)
  }

  startTimer() {
    this.timerInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.startTime) / 1000)
      const remaining = Math.max(30 - elapsed, 0)
      
      if (remaining > 0) {
        this.updateTimer(`Estimated time: ${remaining}s remaining`)
      } else {
        this.updateTimer("Finalizing your cover letter...")
      }
    }, 1000)
  }

  nextAnimationPhase() {
    this.animationPhase = (this.animationPhase + 1) % 3
    
    const phases = [
      {
        step: 1,
        status: "Analyzing your resume and job requirements...",
        subText: "Our AI is reading through your experience to craft the perfect narrative",
        typewriter: "Analyzing Your Background..."
      },
      {
        step: 2,
        status: "Crafting personalized content...",
        subText: "Writing compelling paragraphs that highlight your unique value",
        typewriter: "Writing Your Story..."
      },
      {
        step: 3,
        status: "Optimizing tone and structure...",
        subText: "Fine-tuning the language to match your selected tone and style",
        typewriter: "Perfecting the Details..."
      }
    ]

    const currentPhase = phases[this.animationPhase]
    
    // Update step indicators with smooth transitions
    this.updateStepIndicators(currentPhase.step)
    
    // Update text content with fade effect
    this.updateWithFade(this.statusTextTarget, currentPhase.status)
    this.updateWithFade(this.subTextTarget, currentPhase.subText)
    this.updateWithFade(this.typewriterTarget, currentPhase.typewriter)
  }

  updateStepIndicators(activeStep) {
    this.stepTargets.forEach((step, index) => {
      const stepNumber = index + 1
      const circle = step.querySelector('div')
      const text = step.querySelector('span')
      
      if (stepNumber <= activeStep) {
        // Active or completed step
        circle.classList.remove('bg-gray-300', 'text-gray-500')
        circle.classList.add(stepNumber === activeStep ? 'animate-pulse' : '')
        text.classList.remove('text-gray-500')
        
        if (stepNumber === 1) {
          circle.classList.add('bg-blue-500', 'text-white')
          text.classList.add('text-blue-600', 'font-medium')
        } else if (stepNumber === 2) {
          circle.classList.add('bg-purple-500', 'text-white')
          text.classList.add('text-purple-600', 'font-medium')
        } else {
          circle.classList.add('bg-green-500', 'text-white')
          text.classList.add('text-green-600', 'font-medium')
        }
      } else {
        // Inactive step
        circle.classList.remove('animate-pulse', 'bg-blue-500', 'bg-purple-500', 'bg-green-500', 'text-white')
        circle.classList.add('bg-gray-300', 'text-gray-500')
        text.classList.remove('text-blue-600', 'text-purple-600', 'text-green-600', 'font-medium')
        text.classList.add('text-gray-500')
      }
    })
  }

  updateWithFade(element, newText) {
    if (!element) return
    
    element.style.transition = 'opacity 0.3s ease-in-out'
    element.style.opacity = '0'
    
    setTimeout(() => {
      element.textContent = newText
      element.style.opacity = '1'
    }, 300)
  }

  updateTimer(text) {
    if (this.hasTimerTarget) {
      this.timerTarget.textContent = text
    }
  }

  stopAnimations() {
    if (this.animationInterval) {
      clearInterval(this.animationInterval)
      this.animationInterval = null
    }
    
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }
  }
}