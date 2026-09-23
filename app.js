// app.js - Main Application Controller for SIGEPI
import { authService } from './services/auth.service.js';
import { epiService } from './services/epi.service.js';
import { emprestimoService } from './services/emprestimo.service.js';
import { alertaService } from './services/alerta.service.js';
import { dashboardService } from './services/dashboard.service.js';
import { realtimeService } from './realtime.service.js';

class SigepiApp {
  constructor() {
    this.viewCache = {};
    this.initEvents();
    realtimeService.initSubscriptions();
  }

  initEvents() {
    window.addEventListener('view-changed', (e) => {
      this.loadView(e.detail.view);
    });

    const startView = () => {
      const currentView = (window.Alpine && Alpine.store('app')) ? Alpine.store('app').currentView : 'dashboard';
      this.loadView(currentView);
    };

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', startView);
    } else {
      startView();
    }
  }

  async loadView(viewName) {
    const mainContainer = document.getElementById('main-content');
    const loginContainer = document.getElementById('view-login');

    if (viewName === 'login') {
      if (loginContainer) {
        const html = await this.fetchPageHtml('pages/login.html');
        loginContainer.innerHTML = html;
      }
      return;
    }

    if (!mainContainer) return;

    try {
      let pagePath = `pages/${viewName}.html`;
      if (viewName === 'catalogo-estoque') pagePath = 'pages/catalogo-estoque.html';

      const html = await this.fetchPageHtml(pagePath);
      mainContainer.innerHTML = html;

      if (viewName === 'dashboard') {
        this.initDashboardCharts();
      }
    } catch (err) {
      console.error(`Erro ao carregar a view ${viewName}:`, err);
    }
  }

  async fetchPageHtml(path) {
    if (this.viewCache[path]) return this.viewCache[path];
    const res = await fetch(path);
    if (!res.ok) throw new Error(`Falha ao buscar página ${path}`);
    const html = await res.text();
    this.viewCache[path] = html;
    return html;
  }

  initDashboardCharts() {
    setTimeout(() => {
      const canvas = document.getElementById('giroChart');
      if (!canvas || !window.Chart) return;

      if (window.giroChartInstance) window.giroChartInstance.destroy();

      window.giroChartInstance = new Chart(canvas, {
        type: 'bar',
        data: {
          labels: ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'],
          datasets: [
            {
              label: 'Entradas (Reposição)',
              data: [32, 54, 20, 68, 30, 10, 4],
              backgroundColor: '#5dc2ed',
              borderRadius: 4
            },
            {
              label: 'Saídas (Entregas)',
              data: [26, 45, 50, 30, 62, 14, 6],
              backgroundColor: '#3d608f',
              borderRadius: 4
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { position: 'top' }
          }
        }
      });
    }, 100);
  }

  async handleLogin() {
    const email = document.getElementById('loginEmail')?.value;
    const password = document.getElementById('loginPassword')?.value;
    const { user } = await authService.login(email, password);
    Alpine.store('auth').setUser(user, 'demo-token');
    Alpine.store('notificacao').showToast(`Bem-vindo, ${user.nome}!`, 'success');
    Alpine.store('app').navigate('dashboard');
  }

  async handleSolicitacao() {
    Alpine.store('notificacao').showToast('Solicitação de EPI registrada com sucesso!', 'success');
    Alpine.store('app').navigate('liberacoes-scanner');
  }

  async handleQuickScan() {
    const code = document.getElementById('inputDirectCode')?.value;
    Alpine.store('notificacao').showToast(`Código ${code} verificado com sucesso!`, 'success');
  }
}

window.sigepiApp = new SigepiApp();
