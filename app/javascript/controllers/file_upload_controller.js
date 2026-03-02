import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "fileInput", "filePreview", "fileName", "fileSize"]

  handleDragOver(event) {
    event.preventDefault()
  }

  handleDragEnter(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("dragover")
  }

  handleDragLeave(event) {
    event.preventDefault()
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("dragover")
    }
  }

  handleDrop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      const dt = new DataTransfer()
      dt.items.add(files[0])
      this.fileInputTarget.files = dt.files
      this.showFilePreview(files[0])
    }
  }

  openFileDialog(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (file) {
      this.showFilePreview(file)
    }
  }

  showFilePreview(file) {
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    this.filePreviewTarget.classList.remove("hidden")
  }

  removeFile() {
    this.fileInputTarget.value = ""
    this.filePreviewTarget.classList.add("hidden")
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }
}
