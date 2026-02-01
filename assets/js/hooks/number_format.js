// Hook para formatear números con separadores de miles
// Usa punto como separador de miles (formato argentino)
export const NumberFormat = {
    mounted() {
        this.el.addEventListener("input", (e) => {
            const cursorPosition = e.target.selectionStart;
            const originalLength = e.target.value.length;

            // Remover todo excepto dígitos y coma (para decimales)
            let value = e.target.value.replace(/[^\d,]/g, "");

            // Separar parte entera y decimal
            const parts = value.split(",");
            let integerPart = parts[0];
            const decimalPart = parts[1];

            // Agregar separadores de miles a la parte entera
            if (integerPart) {
                integerPart = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
            }

            // Reconstruir el valor
            let formattedValue = integerPart;
            if (decimalPart !== undefined) {
                formattedValue += "," + decimalPart;
            }

            e.target.value = formattedValue;

            // Ajustar posición del cursor
            const newLength = formattedValue.length;
            const diff = newLength - originalLength;
            const newPosition = cursorPosition + diff;
            e.target.setSelectionRange(newPosition, newPosition);
        });

        // Formatear valor inicial si existe
        if (this.el.value) {
            const value = this.el.value.replace(/[^\d,]/g, "");
            const parts = value.split(",");
            let integerPart = parts[0];
            const decimalPart = parts[1];

            if (integerPart) {
                integerPart = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
            }

            let formattedValue = integerPart;
            if (decimalPart !== undefined) {
                formattedValue += "," + decimalPart;
            }

            this.el.value = formattedValue;
        }
    },

    updated() {
        // Re-formatear si el servidor actualiza el valor
        if (this.el.value && !this.el.value.includes(".")) {
            const value = this.el.value.replace(/[^\d,]/g, "");
            const parts = value.split(",");
            let integerPart = parts[0];
            const decimalPart = parts[1];

            if (integerPart) {
                integerPart = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
            }

            let formattedValue = integerPart;
            if (decimalPart !== undefined) {
                formattedValue += "," + decimalPart;
            }

            this.el.value = formattedValue;
        }
    }
};
