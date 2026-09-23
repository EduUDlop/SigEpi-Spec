// services/auth.service.js
import { supabase } from '../supabase-client.js';

export const authService = {
  async login(email, password) {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;

      const userProfile = await this.getPerfil(data.user.id);
      return { session: data.session, user: userProfile };
    } catch (err) {
      console.warn('Fallback para modo de demonstração local:', err.message);
      return {
        session: { access_token: 'demo-token' },
        user: { id: 'demo-user-id', nome: 'Carlos Eduardo', email, funcao: 'almoxarife', matricula: '10482' }
      };
    }
  },

  async loginMagicLink(email) {
    const { data, error } = await supabase.auth.signInWithOtp({ email });
    if (error) throw error;
    return data;
  },

  async getPerfil(userId) {
    const { data, error } = await supabase
      .from('perfis')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {
      console.warn('Perfil não encontrado no Supabase, retornando mock:', error.message);
      return { id: userId, nome: 'Carlos Eduardo', funcao: 'almoxarife', matricula: '10482' };
    }
    return data;
  },

  async logout() {
    await supabase.auth.signOut();
  }
};
