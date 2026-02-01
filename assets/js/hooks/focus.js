export const Focus = {
    mounted() {
        this.el.focus()
        // Select text if it's an input/textarea
        if (this.el.setSelectionRange) {
            this.el.setSelectionRange(0, this.el.value.length)
        }
    }
}
