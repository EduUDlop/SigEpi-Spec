import { supabase } from '../supabase-client.js';

export const emprestimoService = {
  async listarSolicitacoesPendentes() {
    const { data, error } = await supabase
      .from('emprestimos')
      .select(`
        *,
        epis (*),
        colaborador:perfis!emprestimos_colaborador_id_fkey (*)
      `)
      .eq('status', 'pendente')
      .order('created_at', { ascending: true });

    if (error) throw error;
    return data;
  },

  async solicitarEpi({ epiId, colaboradorId, quantidade = 1, observacao = '' }) {
    const { data, error } = await supabase
      .from('emprestimos')
      .insert([{
        epi_id: epiId,
        colaborador_id: colaboradorId,
        quantidade,
        observacao,
        status: 'pendente'
      }])
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  async liberarEmprestimo(emprestimoId, almoxarifeId) {
    const { data, error } = await supabase
      .from('emprestimos')
      .update({
        status: 'entregue',
        almoxarife_id: almoxarifeId,
        data_emprestimo: new Date().toISOString()
      })
      .eq('id', emprestimoId)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  async devolverEmprestimo(emprestimoId, almoxarifeId) {
    const { data, error } = await supabase
      .from('emprestimos')
      .update({
        status: 'devolvido',
        data_devolucao: new Date().toISOString()
      })
      .eq('id', emprestimoId)
      .select()
      .single();

    if (error) throw error;
    return data;
  }
};
