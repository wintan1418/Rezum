import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "dropZone", "fileInput", "uploadIcon", "fileInfo", "fileName", "fileSize", "submitBtn", "submitText", "loadingText"]

  connect() {
    this.fileSelected_ = false
  }

  openFilePicker(e) {
    e.preventDefault()
    this.fileInputTarget.click()
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0]
    if (!file) return

    if (!this.validateFile(file)) return

    this.showFileInfo(file)
    this.fileSelected_ = true
    this.submitBtnTarget.disabled = false
  }

  dragOver(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.add("border-blue-400", "bg-blue-50/50")
  }

  dragLeave(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.remove("border-blue-400", "bg-blue-50/50")
  }

  drop(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.remove("border-blue-400", "bg-blue-50/50")

    const files = e.dataTransfer.files
    if (files.length === 0) return

    const file = files[0]
    if (!this.validateFile(file)) return

    // Set file on input
    const dt = new DataTransfer()
    dt.items.add(file)
    this.fileInputTarget.files = dt.files

    this.showFileInfo(file)
    this.fileSelected_ = true
    this.submitBtnTarget.disabled = false
  }

  submit(e) {
    if (!this.fileSelected_) {
      e.preventDefault()
      return
    }

    // Show loading state
    this.submitBtnTarget.disabled = true
    this.submitTextTarget.classList.add("hidden")
    this.loadingTextTarget.classList.remove("hidden")
    this.loadingTextTarget.classList.add("inline-flex")

    // Scroll to results on mobile
    setTimeout(() => {
      const results = document.getElementById("ats-results")
      if (results && window.innerWidth < 1024) {
        results.scrollIntoView({ behavior: "smooth", block: "start" })
      }
    }, 500)
  }

  // Private

  validateFile(file) {
    const allowedTypes = [
      "application/pdf",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/msword",
      "text/plain"
    ]
    const maxSize = 10 * 1024 * 1024 // 10MB

    if (!allowedTypes.includes(file.type)) {
      alert("Please upload a PDF, DOCX, or TXT file.")
      return false
    }

    if (file.size > maxSize) {
      alert("File is too large. Maximum size is 10MB.")
      return false
    }

    return true
  }

  showFileInfo(file) {
    this.uploadIconTarget.classList.add("hidden")
    this.fileInfoTarget.classList.remove("hidden")
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
  }

  formatFileSize(bytes) {
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
  }
}
