// services/emprestimo.service.js
import { supabase } from '../supabase-client.js';

export const emprestimoService = {
  async listarEmprestimos(filtros = {}) {
    let query = supabase.from('emprestimos').select(`
      *,
      epis (*),
      colaborador:perfis!emprestimos_colaborador_id_fkey (*),
      almoxarife:perfis!emprestimos_almoxarife_id_fkey (*)
    `);

    if (filtros.status) query = query.eq('status', filtros.status);
    if (filtros.colaborador_id) query = query.eq('colaborador_id', filtros.colaborador_id);

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      console.warn('Erro ao listar empréstimos do Supabase, usando mock local:', error.message);
      return this.getMockEmprestimos();
    }
    return data && data.length ? data : this.getMockEmprestimos();
  },

  async solicitarEmprestimo(solicitacao) {
    const { data, error } = await supabase.from('emprestimos').insert([solicitacao]).select().single();
    if (error) {
      console.warn('Simulando solicitação local:', error.message);
      return { id: `req-${Date.now()}`, ...solicitacao, status: 'pendente', created_at: new Date().toISOString() };
    }
    return data;
  },

  async liberarEmprestimo(id, almoxarifeId) {
    const { data, error } = await supabase
      .from('emprestimos')
      .update({ status: 'entregue', almoxarife_id: almoxarifeId, confirmacao_colaborador: true, confirmacao_colaborador_em: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.warn('Simulando liberação local:', error.message);
      return { id, status: 'entregue', confirmacao_colaborador: true };
    }
    return data;
  },

  getMockEmprestimos() {
    return [
      {
        id: '1',
        codigo_balcao: 'RET-8942',
        status: 'pendente',
        quantidade: 1,
        created_at: new Date().toISOString(),
        colaborador: { nome: 'Carlos Eduardo Silva', matricula: '10482', funcao: 'Eletricista' },
        epis: { tipo: 'Luva Isolante 10kV', marca: 'Ansell', modelo: 'Classe 2', numero_ca: '29.831', quantidade_estoque: 8 }
      },
      {
        id: '2',
        codigo_balcao: 'RET-8939',
        status: 'pendente',
        quantidade: 1,
        created_at: new Date(Date.now() - 14 * 60000).toISOString(),
        colaborador: { nome: 'Juliana Mendes', matricula: '10291', funcao: 'Mecânica Industrial' },
        epis: { tipo: 'Protetor Auricular Concha', marca: '3M', modelo: 'Peltor X1A', numero_ca: '28.532', quantidade_estoque: 15 }
      },
      {
        id: '3',
        codigo_balcao: 'RET-8935',
        status: 'pendente',
        quantidade: 1,
        created_at: new Date(Date.now() - 21 * 60000).toISOString(),
        colaborador: { nome: 'Marcelo Rezende', matricula: '10583', funcao: 'Soldador' },
        epis: { tipo: 'Avental de Raspa & Perneira', marca: 'Zetex', modelo: 'Couro Bovino', numero_ca: '19.402', quantidade_estoque: 5 }
      }
    ];
  }
};
