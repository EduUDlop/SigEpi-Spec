// services/alerta.service.js
import { supabase } from '../supabase-client.js';

export const alertaService = {
  async listarAlertas() {
    const { data, error } = await supabase
      .from('alertas')
      .select('*, epis(*)')
      .order('created_at', { ascending: false });

    if (error) {
      console.warn('Erro ao carregar alertas do Supabase, usando mock local:', error.message);
      return this.getMockAlertas();
    }
    return data && data.length ? data : this.getMockAlertas();
  },

  async marcarComoLido(alertaId) {
    const { error } = await supabase.from('alertas').update({ lido: true }).eq('id', alertaId);
    if (error) console.warn('Erro ao marcar lido:', error.message);
  },

  getMockAlertas() {
    return [
      { id: '1', tipo_alerta: 'validade_7_dias', mensagem: 'Luva Isolante Alta Tensão 10kV (Lote L-902) VENCE EM 6 DIAS — Inspeção Mandatória NR-10', lido: false },
      { id: '2', tipo_alerta: 'estoque_baixo', mensagem: 'Óculos Proteção Antirrisco UV — Restam apenas 4 unidades ativas (Mínimo: 10 un.)', lido: false },
      { id: '3', tipo_alerta: 'emprestimo_atrasado', mensagem: 'Cinto Paraquedista 3 Pontos — Colaborador Marcos Silva (+2 DIAS ATRASO)', lido: false }
    ];
  }
};
