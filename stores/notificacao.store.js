// stores/notificacao.store.js
document.addEventListener('alpine:init', () => {
  Alpine.store('notificacao', {
    count: 3,
    alertas: [],

    setAlertas(list) {
      this.alertas = list;
      this.count = list.filter(a => !a.lido).length;
    },

    showToast(message, type = 'success') {
      const bgColors = {
        success: '#006e26',
        error: '#ba1a1a',
        warning: '#b45309',
        info: '#006685'
      };

      if (window.Toastify) {
        Toastify({
          text: message,
          duration: 3000,
          gravity: 'top',
          position: 'right',
          style: {
            background: bgColors[type] || bgColors.info,
            borderRadius: '8px',
            fontFamily: 'Open Sans, sans-serif',
            fontSize: '14px'
          }
        }).showToast();
      } else {
        console.log(`[Toast ${type}]: ${message}`);
      }
    }
  });
});
