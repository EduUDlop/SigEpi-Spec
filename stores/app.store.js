// stores/app.store.js
document.addEventListener('alpine:init', () => {
  Alpine.store('app', {
    currentView: 'dashboard',
    loading: false,

    navigate(viewName) {
      this.currentView = viewName;
      window.dispatchEvent(new CustomEvent('view-changed', { detail: { view: viewName } }));
    },

    setLoading(state) {
      this.loading = state;
    }
  });
});
