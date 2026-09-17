import { supabase } from '../supabase-client.js';

export const alertaService = {
  async listarAlertas(destinatarioId) {
    let query = supabase
      .from('alertas')
      .select('*, epis(*)')
      .order('created_at', { ascending: false });

    if (destinatarioId) {
      query = query.or(`destinatario_id.eq.${destinatarioId},destinatario_id.is.null`);
    }

    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  async marcarComoLido(alertaId) {
    const { data, error } = await supabase
      .from('alertas')
      .update({ lido: true })
      .eq('id', alertaId)
      .select()
      .single();

    if (error) throw error;
    return data;
  }
};
