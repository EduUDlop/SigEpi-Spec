// realtime.service.js
import { supabase } from './supabase-client.js';

export const realtimeService = {
  initSubscriptions() {
    // 1. Escutar novos empréstimos
    supabase
      .channel('emprestimos-realtime')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'emprestimos' }, (payload) => {
        if (window.Alpine && Alpine.store('notificacao')) {
          Alpine.store('notificacao').showToast('Nova solicitação de EPI recebida!', 'info');
        }
      })
      .subscribe();

    // 2. Escutar novos alertas
    supabase
      .channel('alertas-realtime')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'alertas' }, (payload) => {
        if (window.Alpine && Alpine.store('notificacao')) {
          Alpine.store('notificacao').showToast(`Novo alerta NR-06: ${payload.new.mensagem}`, 'warning');
        }
      })
      .subscribe();
  }
};
