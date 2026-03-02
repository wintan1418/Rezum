import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "inputArea", "textInput", "progress", "progressText"]
  static values = { submitUrl: String }

  connect() {
    this.answers = {}
    this.currentStep = 0
    this.experiences = []
    this.educations = []
    this.tempExperience = {}
    this.tempEducation = {}
    this.collectingExperience = false
    this.collectingEducation = false
    this.experienceSubStep = 0
    this.educationSubStep = 0

    this.questions = [
      { key: "full_name", text: "Hey there! Let's build your resume. What's your full name?", type: "text", placeholder: "e.g. John Doe" },
      { key: "email", text: "Great! What's your email address?", type: "text", placeholder: "you@example.com" },
      { key: "phone", text: "Phone number? (optional — press Enter to skip)", type: "text", placeholder: "+1 234 567 8900", optional: true },
      { key: "location", text: "Where are you located?", type: "text", placeholder: "e.g. Lagos, Nigeria" },
      { key: "target_role", text: "What job title are you targeting?", type: "text", placeholder: "e.g. Software Engineer" },
      { key: "industry", text: "What industry are you in?", type: "select", options: [
        "Technology", "Finance", "Healthcare", "Education", "Marketing",
        "Engineering", "Sales", "Consulting", "Design", "Legal",
        "Human Resources", "Real Estate", "Manufacturing", "Hospitality", "Other"
      ]},
      { key: "experience_level", text: "What's your experience level?", type: "select", options: [
        "Entry Level (0-2 years)", "Mid Level (3-5 years)", "Senior (6-10 years)", "Executive (10+ years)"
      ]},
      { key: "_experience_start", text: "Now let's add your work experience. What was your most recent job title?", type: "text", placeholder: "e.g. Frontend Developer" },
      { key: "skills", text: "List your key skills (separate with commas)", type: "textarea", placeholder: "e.g. JavaScript, React, Project Management, Communication" },
      { key: "certifications", text: "Any certifications? (optional — press Enter to skip)", type: "textarea", placeholder: "e.g. AWS Solutions Architect, PMP", optional: true },
      { key: "additional_info", text: "Anything else? Awards, languages, projects? (optional — press Enter to skip)", type: "textarea", placeholder: "e.g. Fluent in French, Won hackathon 2023", optional: true }
    ]

    this.experienceQuestions = [
      { key: "title", text: null, type: "text", placeholder: "e.g. Frontend Developer" },
      { key: "company", text: "Company name?", type: "text", placeholder: "e.g. Google" },
      { key: "dates", text: "When did you work there?", type: "text", placeholder: "e.g. Jan 2020 - Present" },
      { key: "description", text: "What did you do? Key responsibilities and achievements.", type: "textarea", placeholder: "e.g. Led a team of 5 developers, built the payment system..." },
      { key: "_more", text: "Want to add another job?", type: "yesno" }
    ]

    this.educationQuestions = [
      { key: "degree", text: "What degree or qualification did you earn?", type: "text", placeholder: "e.g. BSc Computer Science" },
      { key: "school", text: "School or institution?", type: "text", placeholder: "e.g. University of Lagos" },
      { key: "dates", text: "When?", type: "text", placeholder: "e.g. 2016 - 2020" },
      { key: "_more", text: "Add another qualification?", type: "yesno" }
    ]

    // Start the conversation
    setTimeout(() => this.showNextQuestion(), 500)
  }

  showNextQuestion() {
    if (this.collectingExperience) {
      this.showExperienceQuestion()
      return
    }

    if (this.collectingEducation) {
      this.showEducationQuestion()
      return
    }

    if (this.currentStep >= this.questions.length) {
      this.finishWizard()
      return
    }

    const q = this.questions[this.currentStep]

    // Handle experience start — transition into experience collection
    if (q.key === "_experience_start") {
      this.collectingExperience = true
      this.experienceSubStep = 0
      this.tempExperience = {}
      // Show the first experience question text from the main questions array
      this.addBotMessage(q.text)
      this.showInput(this.experienceQuestions[0])
      this.updateProgress()
      return
    }

    this.addBotMessage(q.text)
    this.showInput(q)
    this.updateProgress()
  }

  showExperienceQuestion() {
    const q = this.experienceQuestions[this.experienceSubStep]
    if (q.text) this.addBotMessage(q.text)
    this.showInput(q)
    this.updateProgress()
  }

  showEducationQuestion() {
    const q = this.educationQuestions[this.educationSubStep]
    if (q.text) this.addBotMessage(q.text)
    this.showInput(q)
    this.updateProgress()
  }

  showInput(question) {
    const area = this.inputAreaTarget
    area.innerHTML = ""

    if (question.type === "select") {
      const wrapper = document.createElement("div")
      wrapper.className = "space-y-2"
      question.options.forEach(opt => {
        const btn = document.createElement("button")
        btn.className = "w-full text-left px-4 py-3 rounded-xl border border-gray-200 text-sm font-medium text-gray-700 hover:bg-blue-50 hover:border-blue-300 hover:text-blue-700 transition-all"
        btn.textContent = opt
        btn.addEventListener("click", () => this.handleAnswer(opt))
        wrapper.appendChild(btn)
      })
      area.appendChild(wrapper)
    } else if (question.type === "yesno") {
      const wrapper = document.createElement("div")
      wrapper.className = "flex gap-3"
      const yesBtn = document.createElement("button")
      yesBtn.className = "flex-1 px-4 py-3 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 transition-all"
      yesBtn.textContent = "Yes, add more"
      yesBtn.addEventListener("click", () => this.handleAnswer("yes"))
      const noBtn = document.createElement("button")
      noBtn.className = "flex-1 px-4 py-3 rounded-xl text-sm font-semibold text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 transition-all"
      noBtn.textContent = "No, continue"
      noBtn.addEventListener("click", () => this.handleAnswer("no"))
      wrapper.appendChild(yesBtn)
      wrapper.appendChild(noBtn)
      area.appendChild(wrapper)
    } else if (question.type === "textarea") {
      const textarea = document.createElement("textarea")
      textarea.className = "w-full rounded-xl border border-gray-200 shadow-sm text-sm py-3 px-4 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/10 resize-none"
      textarea.rows = 3
      textarea.placeholder = question.placeholder || ""
      textarea.style.fontSize = "16px"
      area.appendChild(textarea)

      const btnRow = document.createElement("div")
      btnRow.className = "flex justify-end mt-2"
      const sendBtn = this.createSendButton()
      sendBtn.addEventListener("click", () => {
        this.handleAnswer(textarea.value)
      })
      btnRow.appendChild(sendBtn)
      area.appendChild(btnRow)

      textarea.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault()
          this.handleAnswer(textarea.value)
        }
      })
      textarea.focus()
    } else {
      // text input
      const wrapper = document.createElement("div")
      wrapper.className = "flex gap-2"
      const input = document.createElement("input")
      input.type = question.key === "email" ? "email" : "text"
      input.className = "flex-1 rounded-xl border border-gray-200 shadow-sm text-sm py-3 px-4 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/10"
      input.placeholder = question.placeholder || ""
      input.style.fontSize = "16px"
      const sendBtn = this.createSendButton()
      sendBtn.addEventListener("click", () => {
        this.handleAnswer(input.value)
      })
      wrapper.appendChild(input)
      wrapper.appendChild(sendBtn)
      area.appendChild(wrapper)

      input.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          e.preventDefault()
          this.handleAnswer(input.value)
        }
      })
      input.focus()
    }

    this.scrollToBottom()
  }

  createSendButton() {
    const btn = document.createElement("button")
    btn.className = "px-4 py-3 rounded-xl text-white bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 transition-all flex-shrink-0"
    btn.innerHTML = `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/></svg>`
    return btn
  }

  handleAnswer(value) {
    const trimmed = (value || "").trim()

    // Handle experience collection
    if (this.collectingExperience) {
      this.handleExperienceAnswer(trimmed)
      return
    }

    // Handle education collection
    if (this.collectingEducation) {
      this.handleEducationAnswer(trimmed)
      return
    }

    const q = this.questions[this.currentStep]

    // Skip optional fields with empty answer
    if (!trimmed && q.optional) {
      this.addUserMessage("(skipped)")
      this.currentStep++
      setTimeout(() => this.showNextQuestion(), 400)
      return
    }

    // Require non-optional fields
    if (!trimmed && !q.optional) {
      this.shakeInput()
      return
    }

    // Validate email format
    if (q.key === "email" && trimmed) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$/
      if (!emailRegex.test(trimmed)) {
        this.addBotMessage("That doesn't look like a valid email. Please try again.")
        this.showInput(q)
        return
      }
    }

    this.addUserMessage(trimmed)
    this.answers[q.key] = trimmed
    this.currentStep++
    setTimeout(() => this.showNextQuestion(), 400)
  }

  handleExperienceAnswer(value) {
    const q = this.experienceQuestions[this.experienceSubStep]

    if (q.key === "_more") {
      this.addUserMessage(value === "yes" ? "Yes, add more" : "No, continue")
      if (value === "yes") {
        // Save current and start new experience
        this.experiences.push({ ...this.tempExperience })
        this.tempExperience = {}
        this.experienceSubStep = 0
        this.addBotMessage("What was your next job title?")
        setTimeout(() => this.showExperienceQuestion(), 400)
      } else {
        // Save and move to education
        this.experiences.push({ ...this.tempExperience })
        this.tempExperience = {}
        this.collectingExperience = false
        this.collectingEducation = true
        this.educationSubStep = 0
        this.tempEducation = {}
        this.currentStep++ // Move past _experience_start
        setTimeout(() => {
          this.addBotMessage("Now let's add your education. What degree or qualification did you earn?")
          this.showInput(this.educationQuestions[0])
          this.updateProgress()
        }, 400)
      }
      return
    }

    if (!value && q.key !== "description") {
      this.shakeInput()
      return
    }

    this.addUserMessage(value || "(skipped)")
    this.tempExperience[q.key] = value
    this.experienceSubStep++
    setTimeout(() => this.showExperienceQuestion(), 400)
  }

  handleEducationAnswer(value) {
    const q = this.educationQuestions[this.educationSubStep]

    if (q.key === "_more") {
      this.addUserMessage(value === "yes" ? "Yes, add more" : "No, continue")
      if (value === "yes") {
        this.educations.push({ ...this.tempEducation })
        this.tempEducation = {}
        this.educationSubStep = 0
        this.addBotMessage("What degree or qualification?")
        setTimeout(() => this.showEducationQuestion(), 400)
      } else {
        this.educations.push({ ...this.tempEducation })
        this.tempEducation = {}
        this.collectingEducation = false
        // Continue to skills question
        setTimeout(() => this.showNextQuestion(), 400)
      }
      return
    }

    if (!value) {
      this.shakeInput()
      return
    }

    this.addUserMessage(value)
    this.tempEducation[q.key] = value
    this.educationSubStep++
    setTimeout(() => this.showEducationQuestion(), 400)
  }

  addBotMessage(text) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex items-start gap-3 animate-fade-in"

    wrapper.innerHTML = `
      <div class="w-8 h-8 rounded-full bg-gradient-to-br from-blue-600 to-purple-600 flex items-center justify-center flex-shrink-0 shadow-sm">
        <span class="text-white text-xs font-bold">R</span>
      </div>
      <div class="max-w-[80%] bg-white rounded-2xl rounded-tl-md px-4 py-3 shadow-sm border border-gray-100">
        <p class="text-sm text-gray-800 leading-relaxed typing-text"></p>
      </div>
    `

    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()

    // Typing animation
    const textEl = wrapper.querySelector(".typing-text")
    this.typeText(textEl, text)
  }

  typeText(element, text, speed = 15) {
    let i = 0
    const interval = setInterval(() => {
      if (i < text.length) {
        element.textContent += text[i]
        i++
        this.scrollToBottom()
      } else {
        clearInterval(interval)
      }
    }, speed)
  }

  addUserMessage(text) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex justify-end animate-fade-in"
    wrapper.innerHTML = `
      <div class="max-w-[80%] bg-gradient-to-r from-blue-600 to-purple-600 rounded-2xl rounded-tr-md px-4 py-3 shadow-sm">
        <p class="text-sm text-white leading-relaxed">${this.escapeHtml(text)}</p>
      </div>
    `
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
  }

  updateProgress() {
    const mainSteps = this.questions.length
    const totalEstimate = mainSteps + 8
    const completed = this.currentStep + (this.collectingExperience ? 1 : 0) + (this.collectingEducation ? 1 : 0)
    const pct = Math.min(Math.round((completed / totalEstimate) * 100), 95)

    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${pct}%`
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${pct}% complete`
    }
  }

  shakeInput() {
    const area = this.inputAreaTarget
    area.classList.add("animate-shake")
    setTimeout(() => area.classList.remove("animate-shake"), 500)
  }

  scrollToBottom() {
    const container = this.messagesTarget
    requestAnimationFrame(() => {
      container.scrollTop = container.scrollHeight
    })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  finishWizard() {
    this.inputAreaTarget.innerHTML = ""

    if (this.hasProgressTarget) {
      this.progressTarget.style.width = "100%"
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = "100% complete"
    }

    this.addBotMessage("Awesome! I have everything I need. Building your resume now...")

    // Show loading state
    setTimeout(() => {
      this.showGeneratingState()
      this.submitData()
    }, 1500)
  }

  showGeneratingState() {
    const area = this.inputAreaTarget
    area.innerHTML = `
      <div class="text-center py-6">
        <div class="inline-flex items-center gap-3 px-5 py-3 bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl border border-blue-100">
          <svg class="w-5 h-5 text-blue-600 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm font-medium text-blue-700">AI is crafting your resume...</span>
        </div>
        <p class="text-xs text-gray-400 mt-3">This usually takes 15-30 seconds</p>
      </div>
    `
  }

  submitData() {
    const payload = {
      ...this.answers,
      experiences: this.experiences,
      educations: this.educations
    }

    // Map experience level to short form
    const levelMap = {
      "Entry Level (0-2 years)": "entry",
      "Mid Level (3-5 years)": "mid",
      "Senior (6-10 years)": "senior",
      "Executive (10+ years)": "executive"
    }
    if (payload.experience_level) {
      payload.experience_level = levelMap[payload.experience_level] || payload.experience_level
    }

    // Map industry to snake_case
    if (payload.industry) {
      payload.industry = payload.industry.toLowerCase().replace(/\s+/g, "_")
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.submitUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ wizard: payload })
    })
    .then(response => response.json())
    .then(data => {
      if (data.redirect_url) {
        window.location.href = data.redirect_url
      } else if (data.error) {
        this.showError(data.error)
      }
    })
    .catch(error => {
      console.error("Wizard submit error:", error)
      this.showError("Something went wrong. Please try again.")
    })
  }

  showError(message) {
    this.inputAreaTarget.innerHTML = `
      <div class="text-center py-4">
        <div class="inline-flex items-center gap-2 px-4 py-3 bg-red-50 rounded-xl border border-red-200">
          <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
          <span class="text-sm font-medium text-red-700">${this.escapeHtml(message)}</span>
        </div>
        <button onclick="window.location.reload()" class="mt-3 text-sm text-blue-600 hover:text-blue-700 font-medium">Try again</button>
      </div>
    `
  }
}
