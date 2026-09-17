import { supabase } from '../supabase-client.js';

export const dashboardService = {
  async getKPIs() {
    const { count: totalEstoque } = await supabase
      .from('epis')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'ativo');

    const { count: validadeCritica } = await supabase
      .from('epis')
      .select('*', { count: 'exact', head: true })
      .lte('data_validade', new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]);

    const { count: solicitacoesPendentes } = await supabase
      .from('emprestimos')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pendente');

    const { count: devolucoesAtrasadas } = await supabase
      .from('emprestimos')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'atrasado');

    return {
      totalEstoque: totalEstoque || 0,
      validadeCritica: validadeCritica || 0,
      solicitacoesPendentes: solicitacoesPendentes || 0,
      devolucoesAtrasadas: devolucoesAtrasadas || 0
    };
  },

  async getTopEstoqueCritico() {
    const { data, error } = await supabase
      .from('epis')
      .select('*')
      .order('quantidade_estoque', { ascending: true })
      .limit(5);

    if (error) throw error;
    return data;
  }
};
