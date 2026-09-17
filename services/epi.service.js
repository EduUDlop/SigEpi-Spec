import { supabase } from '../supabase-client.js';

export const epiService = {
  async listarEpis({ busca = '', categoria = '', status = '', page = 1, limit = 20 } = {}) {
    let query = supabase.from('epis').select('*', { count: 'exact' });

    if (busca) {
      query = query.or(`tipo.ilike.%${busca}%,marca.ilike.%${busca}%,modelo.ilike.%${busca}%,numero_ca.ilike.%${busca}%`);
    }
    if (categoria) {
      query = query.eq('tipo', categoria);
    }
    if (status) {
      query = query.eq('status', status);
    }

    const start = (page - 1) * limit;
    const end = start + limit - 1;
    query = query.range(start, end).order('created_at', { ascending: false });

    const { data, count, error } = await query;
    if (error) throw error;
    return { epis: data, total: count };
  },

  async getEpiById(id) {
    const { data, error } = await supabase
      .from('epis')
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return data;
  },

  async cadastrarEpi(epiData) {
    const { data, error } = await supabase.from('epis').insert([epiData]).select().single();
    if (error) throw error;
    return data;
  },

  async atualizarEpi(id, epiData) {
    const { data, error } = await supabase.from('epis').update(epiData).eq('id', id).select().single();
    if (error) throw error;
    return data;
  }
};
