import { Controller } from "@hotwired/stimulus"

// Toolbar for the group email template editor: inserts {{placeholders}} and
// links selected text to the member's personal link.
export default class extends Controller {
  static targets = ["editor", "message"]

  connect() {
    this.rejectFile = this.rejectFile.bind(this)
    this.element.addEventListener("trix-file-accept", this.rejectFile)
  }

  disconnect() {
    this.element.removeEventListener("trix-file-accept", this.rejectFile)
  }

  // Keep focus (and the selection) in the editor when a helper button is pressed.
  keepFocus(event) {
    event.preventDefault()
  }

  insert(event) {
    this.editor.insertString(`{{${event.params.placeholder}}}`)
    this.say("")
  }

  linkSelection() {
    const [start, end] = this.editor.getSelectedRange()
    if (start === end) {
      this.say("First highlight the words you want to turn into the link, then click “Link selected text”.")
      return
    }
    this.editor.activateAttribute("href", "{{link}}")
    this.say("Linked! Those words will open each person's own link.")
  }

  rejectFile(event) {
    event.preventDefault()
    this.say("Images and file attachments can't be added to emails.")
  }

  say(text) {
    if (this.hasMessageTarget) this.messageTarget.textContent = text
  }

  get editor() {
    return this.editorTarget.editor
  }
}
