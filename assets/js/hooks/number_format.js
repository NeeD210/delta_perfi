// Hook para formatear números con separadores de miles (formato argentino)
// 
// FORMATO:
// - Separador visual de miles: punto (.)  → solo para display
// - Separador decimal del usuario: coma (,) → el único aceptado
// - El punto (.) está BLOQUEADO como input del usuario
//
// FLUJO:
// User escribe "1400" → display "1.400" → server recibe "1400"
// User escribe "1400,50" → display "1.400,50" → server recibe "1400.50"
//
// MECANISMO:
// Antes del blur, reemplaza temporalmente el value del input con el raw value
// para que phx-blur envíe el número limpio. Luego restaura el display.
export const NumberFormat = {
    mounted() {
        this._rawValue = this._displayToRaw(this.el.value) || "";

        this.el.addEventListener("input", (e) => {
            const cursorPosition = e.target.selectionStart;
            const originalLength = e.target.value.length;

            // Permitir SOLO dígitos y coma. Rechazar punto y todo lo demás.
            let value = e.target.value.replace(/[^\d,]/g, "");

            // Solo permitir una coma
            const commaIndex = value.indexOf(",");
            if (commaIndex !== -1) {
                const beforeComma = value.slice(0, commaIndex);
                const afterComma = value.slice(commaIndex + 1).replace(/,/g, "");
                value = beforeComma + "," + afterComma;
            }

            // Separar parte entera y decimal
            const parts = value.split(",");
            let integerPart = parts[0] || "";
            const decimalPart = parts[1];

            // Agregar separadores de miles (punto) a la parte entera — visual only
            if (integerPart) {
                integerPart = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
            }

            // Reconstruir display value
            let displayValue = integerPart;
            if (decimalPart !== undefined) {
                displayValue += "," + decimalPart;
            }

            e.target.value = displayValue;
            this._rawValue = this._displayToRaw(displayValue);

            // Ajustar posición del cursor
            const newLength = displayValue.length;
            const diff = newLength - originalLength;
            const newPosition = Math.max(0, cursorPosition + diff);
            e.target.setSelectionRange(newPosition, newPosition);
        });

        // CLAVE: Antes del blur, poner el raw value en el input
        // para que phx-blur envíe el número limpio al server
        this.el.addEventListener("blur", (_e) => {
            const displayValue = this.el.value;
            this._rawValue = this._displayToRaw(displayValue);
            // Temporalmente poner raw value para que LiveView lo lea
            this.el.value = this._rawValue;
            // Restaurar display después de que LiveView procese el evento
            requestAnimationFrame(() => {
                // Solo restaurar si el server no actualizó el valor
                if (this.el.value === this._rawValue) {
                    this.el.value = displayValue;
                }
            });
        });

        // Formatear valor inicial si existe
        this._formatInitialValue();
    },

    updated() {
        // Re-formatear si el servidor actualiza el valor
        this._formatInitialValue();
    },

    // Convierte display → raw: "1.400,50" → "1400.50", "1.400" → "1400"
    _displayToRaw(displayValue) {
        if (!displayValue) return "";
        return displayValue.replace(/\./g, "").replace(",", ".");
    },

    // Convierte raw → display: "1400.50" → "1.400,50", "1400" → "1.400"
    _rawToDisplay(rawValue) {
        if (!rawValue) return "";

        let value = rawValue;
        // Convertir punto decimal a coma para display
        value = value.replace(".", ",");

        const parts = value.split(",");
        let integerPart = parts[0] || "";
        const decimalPart = parts[1];

        if (integerPart) {
            integerPart = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
        }

        let displayValue = integerPart;
        if (decimalPart !== undefined) {
            displayValue += "," + decimalPart;
        }

        return displayValue;
    },

    // Formatea el valor actual del input para display
    _formatInitialValue() {
        if (!this.el.value) return;

        let value = this.el.value;

        // Si el valor viene del server como raw (ej: "1400" o "1400.5"),
        // convertir a display format
        if (!value.includes(",") && !value.match(/\.\d{3}(?:\.|$)/)) {
            // Es un raw value del server, convertir a display
            this.el.value = this._rawToDisplay(value);
            this._rawValue = value;
        } else {
            // Ya tiene formato display, solo sincronizar raw
            this._rawValue = this._displayToRaw(value);
        }
    }
};
