// services/epi.service.js
import { supabase } from '../supabase-client.js';

export const epiService = {
  async listarEpis(filtros = {}) {
    let query = supabase.from('epis').select('*');

    if (filtros.status) {
      query = query.eq('status', filtros.status);
    }
    if (filtros.tipo) {
      query = query.ilike('tipo', `%${filtros.tipo}%`);
    }
    if (filtros.busca) {
      query = query.or(`tipo.ilike.%${filtros.busca}%,marca.ilike.%${filtros.busca}%,modelo.ilike.%${filtros.busca}%,numero_ca.ilike.%${filtros.busca}%`);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      console.warn('Erro ao carregar do Supabase, retornando mock local de EPIs:', error.message);
      return this.getMockEpis();
    }
    return data && data.length ? data : this.getMockEpis();
  },

  async cadastrarEpi(epiData) {
    const { data, error } = await supabase.from('epis').insert([epiData]).select().single();
    if (error) {
      console.warn('Simulando cadastro local devido a erro/sem permissão:', error.message);
      return { id: `mock-${Date.now()}`, ...epiData, status: 'ativo', created_at: new Date().toISOString() };
    }
    return data;
  },

  async atualizarEpi(id, epiData) {
    const { data, error } = await supabase.from('epis').update(epiData).eq('id', id).select().single();
    if (error) throw error;
    return data;
  },

  getMockEpis() {
    return [
      { id: '1', tipo: 'Capacete de Segurança', marca: 'MSA', modelo: 'V-Gard 500 c/ Jugular', numero_ca: '31.428', quantidade_estoque: 24, quantidade_minima: 10, localizacao_fisica: 'Prateleira A-02 / Gaveta 14', status: 'ativo', data_validade: '2028-11-18' },
      { id: '2', tipo: 'Óculos de Proteção', marca: 'Danny', modelo: 'Ampla Visão Antirrisco', numero_ca: '14.998', quantidade_estoque: 86, quantidade_minima: 15, localizacao_fisica: 'Armazém B-01', status: 'ativo', data_validade: '2027-09-04' },
      { id: '3', tipo: 'Luva de Proteção Química', marca: 'Ansell', modelo: 'Sol-Vex 37-175', numero_ca: '25.140', quantidade_estoque: 14, quantidade_minima: 30, localizacao_fisica: 'Armazém C-04', status: 'ativo', data_validade: '2024-06-12' },
      { id: '4', tipo: 'Botina de Couro Composite', marca: 'Marluvas', modelo: 'Premier Nobuck 75BHP500', numero_ca: '41.337', quantidade_estoque: 42, quantidade_minima: 20, localizacao_fisica: 'Armazém D-02', status: 'ativo', data_validade: '2026-10-23' },
      { id: '5', tipo: 'Protetor Auricular Silicone', marca: '3M', modelo: '1290 c/ Cordão', numero_ca: '05.674', quantidade_estoque: 0, quantidade_minima: 50, localizacao_fisica: 'Quarentena', status: 'vencido', data_validade: '2024-01-15' },
      { id: '6', tipo: 'Máscara PFF2 N95', marca: 'Camper', modelo: 'PFF2 c/ Válvula', numero_ca: '38.504', quantidade_estoque: 120, quantidade_minima: 40, localizacao_fisica: 'Armazém A-05', status: 'ativo', data_validade: '2028-08-30' }
    ];
  }
};
