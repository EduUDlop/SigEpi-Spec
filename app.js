import { authService } from './services/auth.service.js';
import { epiService } from './services/epi.service.js';
import { emprestimoService } from './services/emprestimo.service.js';
import { dashboardService } from './services/dashboard.service.js';
import { alertaService } from './services/alerta.service.js';

document.addEventListener('alpine:init', () => {
  // Store Global de Autenticação
  Alpine.store('auth', {
    user: {
      id: 'demo-user-id',
      nome: 'Carlos Eduardo',
      funcao: 'Técnico SST',
      email: 'carlos.eduardo@empresa.com'
    },
    isAuthenticated: true,
    async init() {
      try {
        const currentUser = await authService.getCurrentUser();
        if (currentUser) {
          this.user = currentUser.perfil || currentUser;
          this.isAuthenticated = true;
        }
      } catch (e) {
        console.warn('Modo demonstração/Supabase local ativo:', e);
      }
    }
  });

  // Store Global da Aplicação (Roteamento & UI)
  Alpine.store('app', {
    currentRoute: 'dashboard',
    setRoute(route) {
      this.currentRoute = route;
      window.location.hash = route;
    },
    init() {
      const hash = window.location.hash.replace('#', '');
      if (hash) {
        this.currentRoute = hash;
      }
      window.addEventListener('hashchange', () => {
        const newHash = window.location.hash.replace('#', '');
        if (newHash) this.currentRoute = newHash;
      });
    }
  });

  // Store Global de Notificações / Alertas
  Alpine.store('notificacoes', {
    alertas: [],
    naoLidosCount: 0,
    async carregarAlertas() {
      try {
        const authStore = Alpine.store('auth');
        const data = await alertaService.listarAlertas(authStore.user?.id);
        if (data) {
          this.alertas = data;
          this.naoLidosCount = data.filter(a => !a.lido).length;
        }
      } catch (e) {
        console.warn('Alertas carregados em modo estático/demo:', e);
      }
    }
  });
});
