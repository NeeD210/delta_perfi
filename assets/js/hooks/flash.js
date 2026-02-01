export const Flash = {
  mounted() {
    this.showTimer = setTimeout(() => {
      this.el.dispatchEvent(new Event("phx:hide-flash", { bubbles: true }))
    }, 5000)

    this.el.addEventListener("phx:hide-flash", () => {
      // Trigger the same logic as clicking the close button
      // We can use LiveView's JS.push if we want to be fancy, 
      // but simpler is to just click the element if it has phx-click
      this.el.click()
    })
  },
  destroyed() {
    clearTimeout(this.showTimer)
  }
}
