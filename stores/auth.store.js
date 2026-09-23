// stores/auth.store.js
document.addEventListener('alpine:init', () => {
  Alpine.store('auth', {
    user: JSON.parse(localStorage.getItem('sigepi_user')) || {
      id: 'demo-user-id',
      nome: 'Carlos Eduardo',
      email: 'carlos.eduardo@empresa.com',
      funcao: 'almoxarife',
      matricula: '10482'
    },
    isAuthenticated: !!localStorage.getItem('sigepi_user_token') || true,

    setUser(userData, token) {
      this.user = userData;
      this.isAuthenticated = true;
      if (userData) localStorage.setItem('sigepi_user', JSON.stringify(userData));
      if (token) localStorage.setItem('sigepi_user_token', token);
    },

    logout() {
      this.user = null;
      this.isAuthenticated = false;
      localStorage.removeItem('sigepi_user');
      localStorage.removeItem('sigepi_user_token');
      Alpine.store('app').navigate('login');
    }
  });
});
