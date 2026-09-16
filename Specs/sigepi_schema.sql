-- ============================================================================
-- SIGEPI — Sistema de Gestão de Equipamentos de Proteção Individual
-- Esquema SQL completo para Supabase (PostgreSQL 15+)
-- Execute no SQL Editor do Supabase, aba "New query"
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. EXTENSÕES
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron"; -- Opcional: para jobs automáticos de alertas

-- ----------------------------------------------------------------------------
-- 1. TABELAS
-- ----------------------------------------------------------------------------

-- 1.1 PERFIS (extensão da tabela auth.users do Supabase Auth)
CREATE TABLE IF NOT EXISTS perfis (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nome TEXT NOT NULL,
  email TEXT NOT NULL,
  matricula TEXT UNIQUE,
  funcao TEXT NOT NULL CHECK (funcao IN ('almoxarife', 'tecnico_campo', 'sst', 'admin', 'gestor')),
  telefone TEXT,
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE perfis IS 'Perfis de usuários vinculados à autenticação do Supabase';
COMMENT ON COLUMN perfis.funcao IS 'Papéis: almoxarife, tecnico_campo, sst, admin, gestor';

-- 1.2 EPIS
CREATE TABLE IF NOT EXISTS epis (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo TEXT NOT NULL,
  marca TEXT,
  modelo TEXT,
  numero_ca TEXT NOT NULL,
  data_fabricacao DATE,
  data_validade DATE NOT NULL,
  quantidade_estoque INTEGER NOT NULL DEFAULT 0,
  quantidade_minima INTEGER NOT NULL DEFAULT 1,
  localizacao_fisica TEXT,
  foto_url TEXT,
  status TEXT NOT NULL CHECK (status IN ('ativo', 'vencido', 'baixado', 'em_uso')) DEFAULT 'ativo',
  ca_validado BOOLEAN NOT NULL DEFAULT false,
  ca_validado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE epis IS 'Cadastro de Equipamentos de Proteção Individual';
COMMENT ON COLUMN epis.numero_ca IS 'Certificado de Aprovação do Ministério do Trabalho';
COMMENT ON COLUMN epis.status IS 'ativo, vencido, baixado, em_uso';

-- 1.3 EMPRESTIMOS
CREATE TABLE IF NOT EXISTS emprestimos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  epi_id UUID NOT NULL REFERENCES epis(id) ON DELETE RESTRICT,
  colaborador_id UUID NOT NULL REFERENCES perfis(id) ON DELETE RESTRICT,
  almoxarife_id UUID REFERENCES perfis(id) ON DELETE SET NULL,
  quantidade INTEGER NOT NULL DEFAULT 1,
  data_emprestimo TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_prevista_devolucao DATE,
  data_devolucao TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN ('pendente', 'entregue', 'devolvido', 'trocado', 'atrasado')) DEFAULT 'pendente',
  motivo_troca TEXT,
  observacao TEXT,
  confirmacao_colaborador BOOLEAN NOT NULL DEFAULT false,
  confirmacao_colaborador_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE emprestimos IS 'Registro de empréstimos, devoluções e trocas de EPIs';
COMMENT ON COLUMN emprestimos.status IS 'pendente, entregue, devolvido, trocado, atrasado';

-- 1.4 MOVIMENTACOES (log de auditoria)
CREATE TABLE IF NOT EXISTS movimentacoes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  epi_id UUID NOT NULL REFERENCES epis(id) ON DELETE RESTRICT,
  tipo_movimentacao TEXT NOT NULL CHECK (tipo_movimentacao IN ('entrada', 'saida', 'devolucao', 'troca', 'baixa', 'ajuste')),
  quantidade INTEGER NOT NULL,
  quantidade_anterior INTEGER NOT NULL,
  quantidade_nova INTEGER NOT NULL,
  responsavel_id UUID NOT NULL REFERENCES perfis(id) ON DELETE RESTRICT,
  colaborador_id UUID REFERENCES perfis(id) ON DELETE SET NULL,
  emprestimo_id UUID REFERENCES emprestimos(id) ON DELETE SET NULL,
  observacao TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE movimentacoes IS 'Log de auditoria de todas as movimentações de estoque';

-- 1.5 ALERTAS
CREATE TABLE IF NOT EXISTS alertas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  epi_id UUID REFERENCES epis(id) ON DELETE SET NULL,
  tipo_alerta TEXT NOT NULL CHECK (tipo_alerta IN ('validade_30_dias', 'validade_7_dias', 'validade_vencida', 'estoque_baixo', 'emprestimo_atrasado')),
  mensagem TEXT NOT NULL,
  lido BOOLEAN NOT NULL DEFAULT false,
  destinatario_id UUID REFERENCES perfis(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE alertas IS 'Notificações automáticas de validade, estoque e atrasos';

-- 1.6 CONFIGURACOES
CREATE TABLE IF NOT EXISTS configuracoes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chave TEXT UNIQUE NOT NULL,
  valor TEXT NOT NULL,
  descricao TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE configuracoes IS 'Parametrização do sistema';

-- ----------------------------------------------------------------------------
-- 2. ÍNDICES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_perfis_funcao ON perfis(funcao);
CREATE INDEX IF NOT EXISTS idx_perfis_ativo ON perfis(ativo);

CREATE INDEX IF NOT EXISTS idx_epis_status ON epis(status);
CREATE INDEX IF NOT EXISTS idx_epis_data_validade ON epis(data_validade);
CREATE INDEX IF NOT EXISTS idx_epis_tipo ON epis(tipo);
CREATE INDEX IF NOT EXISTS idx_epis_numero_ca ON epis(numero_ca);

CREATE INDEX IF NOT EXISTS idx_emprestimos_status ON emprestimos(status);
CREATE INDEX IF NOT EXISTS idx_emprestimos_colaborador ON emprestimos(colaborador_id);
CREATE INDEX IF NOT EXISTS idx_emprestimos_epi ON emprestimos(epi_id);
CREATE INDEX IF NOT EXISTS idx_emprestimos_data_emprestimo ON emprestimos(data_emprestimo);

CREATE INDEX IF NOT EXISTS idx_movimentacoes_epi ON movimentacoes(epi_id);
CREATE INDEX IF NOT EXISTS idx_movimentacoes_created ON movimentacoes(created_at);
CREATE INDEX IF NOT EXISTS idx_movimentacoes_tipo ON movimentacoes(tipo_movimentacao);

CREATE INDEX IF NOT EXISTS idx_alertas_lido ON alertas(lido);
CREATE INDEX IF NOT EXISTS idx_alertas_destinatario ON alertas(destinatario_id);
CREATE INDEX IF NOT EXISTS idx_alertas_tipo ON alertas(tipo_alerta);
CREATE INDEX IF NOT EXISTS idx_alertas_created ON alertas(created_at);

-- ----------------------------------------------------------------------------
-- 3. FUNÇÕES AUXILIARES
-- ----------------------------------------------------------------------------

-- 3.1 Atualização automática de updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3.2 Trigger de auditoria de movimentação (emprestimo)
CREATE OR REPLACE FUNCTION log_movimentacao_emprestimo()
RETURNS TRIGGER AS $$
DECLARE
  v_quantidade_anterior INTEGER;
  v_quantidade_nova INTEGER;
BEGIN
  -- INSERT com status 'entregue' = SAIDA de estoque
  IF TG_OP = 'INSERT' AND NEW.status = 'entregue' THEN
    SELECT quantidade_estoque INTO v_quantidade_anterior FROM epis WHERE id = NEW.epi_id;
    v_quantidade_nova := v_quantidade_anterior - NEW.quantidade;

    INSERT INTO movimentacoes (
      epi_id, tipo_movimentacao, quantidade,
      quantidade_anterior, quantidade_nova,
      responsavel_id, colaborador_id, emprestimo_id, observacao
    ) VALUES (
      NEW.epi_id, 'saida', NEW.quantidade,
      v_quantidade_anterior, v_quantidade_nova,
      NEW.almoxarife_id, NEW.colaborador_id, NEW.id, 'Empréstimo registrado'
    );

    UPDATE epis SET quantidade_estoque = v_quantidade_nova WHERE id = NEW.epi_id;
  END IF;

  -- UPDATE de 'entregue' para 'devolvido' = DEVOLUCAO ao estoque
  IF TG_OP = 'UPDATE' AND OLD.status = 'entregue' AND NEW.status = 'devolvido' THEN
    SELECT quantidade_estoque INTO v_quantidade_anterior FROM epis WHERE id = NEW.epi_id;
    v_quantidade_nova := v_quantidade_anterior + NEW.quantidade;

    INSERT INTO movimentacoes (
      epi_id, tipo_movimentacao, quantidade,
      quantidade_anterior, quantidade_nova,
      responsavel_id, colaborador_id, emprestimo_id, observacao
    ) VALUES (
      NEW.epi_id, 'devolucao', NEW.quantidade,
      v_quantidade_anterior, v_quantidade_nova,
      NEW.almoxarife_id, NEW.colaborador_id, NEW.id, 'Devolução registrada'
    );

    UPDATE epis SET quantidade_estoque = v_quantidade_nova WHERE id = NEW.epi_id;
  END IF;

  -- UPDATE de 'entregue' para 'trocado' = TROCA (baixa do antigo + saida do novo)
  IF TG_OP = 'UPDATE' AND OLD.status = 'entregue' AND NEW.status = 'trocado' THEN
    SELECT quantidade_estoque INTO v_quantidade_anterior FROM epis WHERE id = NEW.epi_id;
    v_quantidade_nova := v_quantidade_anterior + NEW.quantidade;

    INSERT INTO movimentacoes (
      epi_id, tipo_movimentacao, quantidade,
      quantidade_anterior, quantidade_nova,
      responsavel_id, colaborador_id, emprestimo_id, observacao
    ) VALUES (
      NEW.epi_id, 'troca', NEW.quantidade,
      v_quantidade_anterior, v_quantidade_nova,
      NEW.almoxarife_id, NEW.colaborador_id, NEW.id,
      COALESCE(NEW.motivo_troca, 'Troca registrada')
    );

    UPDATE epis SET quantidade_estoque = v_quantidade_nova WHERE id = NEW.epi_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3.3 Função para atualizar status de EPIs vencidos
CREATE OR REPLACE FUNCTION atualizar_status_epis_vencidos()
RETURNS void AS $$
BEGIN
  UPDATE epis
  SET status = 'vencido'
  WHERE data_validade < CURRENT_DATE
    AND status NOT IN ('vencido', 'baixado');
END;
$$ LANGUAGE plpgsql;

-- 3.4 Função para verificar empréstimos atrasados
CREATE OR REPLACE FUNCTION verificar_emprestimos_atrasados()
RETURNS void AS $$
BEGIN
  UPDATE emprestimos
  SET status = 'atrasado'
  WHERE data_prevista_devolucao < CURRENT_DATE
    AND status = 'entregue';
END;
$$ LANGUAGE plpgsql;

-- 3.5 Função para gerar alertas de validade automaticamente
CREATE OR REPLACE FUNCTION gerar_alertas_validade()
RETURNS void AS $$
DECLARE
  v_epi RECORD;
  v_dias_alerta INTEGER;
BEGIN
  -- Obtém configuração de dias de alerta (default 30)
  SELECT COALESCE(NULLIF(valor, '')::INTEGER, 30)
  INTO v_dias_alerta
  FROM configuracoes
  WHERE chave = 'dias_alerta_validade';

  -- Alerta 30 dias (ou conforme configuração)
  FOR v_epi IN
    SELECT id, tipo, marca, modelo, data_validade
    FROM epis
    WHERE data_validade <= CURRENT_DATE + (v_dias_alerta || ' days')::INTERVAL
      AND data_validade > CURRENT_DATE
      AND status = 'ativo'
  LOOP
    INSERT INTO alertas (epi_id, tipo_alerta, mensagem, destinatario_id)
    SELECT
      v_epi.id,
      'validade_30_dias',
      'EPI ' || v_epi.tipo || ' ' || COALESCE(v_epi.marca, '') || ' (CA: ' || v_epi.modelo || ') vence em ' || v_epi.data_validade,
      p.id
    FROM perfis p
    WHERE p.funcao IN ('almoxarife', 'sst', 'admin')
      AND p.ativo = true
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- Alerta 7 dias
  FOR v_epi IN
    SELECT id, tipo, marca, modelo, data_validade
    FROM epis
    WHERE data_validade <= CURRENT_DATE + INTERVAL '7 days'
      AND data_validade > CURRENT_DATE
      AND status = 'ativo'
  LOOP
    INSERT INTO alertas (epi_id, tipo_alerta, mensagem, destinatario_id)
    SELECT
      v_epi.id,
      'validade_7_dias',
      'EPI ' || v_epi.tipo || ' ' || COALESCE(v_epi.marca, '') || ' vence em 7 dias: ' || v_epi.data_validade,
      p.id
    FROM perfis p
    WHERE p.funcao IN ('almoxarife', 'sst', 'admin')
      AND p.ativo = true
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- Alerta vencido
  FOR v_epi IN
    SELECT id, tipo, marca, modelo, data_validade
    FROM epis
    WHERE data_validade < CURRENT_DATE
      AND status = 'vencido'
  LOOP
    INSERT INTO alertas (epi_id, tipo_alerta, mensagem, destinatario_id)
    SELECT
      v_epi.id,
      'validade_vencida',
      'EPI ' || v_epi.tipo || ' ' || COALESCE(v_epi.marca, '') || ' VENCEU em ' || v_epi.data_validade || ' — bloquear saída imediatamente',
      p.id
    FROM perfis p
    WHERE p.funcao IN ('almoxarife', 'sst', 'admin')
      AND p.ativo = true
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3.6 Função para gerar alertas de estoque baixo
CREATE OR REPLACE FUNCTION gerar_alertas_estoque_baixo()
RETURNS void AS $$
DECLARE
  v_epi RECORD;
BEGIN
  FOR v_epi IN
    SELECT id, tipo, marca, modelo, quantidade_estoque, quantidade_minima
    FROM epis
    WHERE quantidade_estoque <= quantidade_minima
      AND status = 'ativo'
  LOOP
    INSERT INTO alertas (epi_id, tipo_alerta, mensagem, destinatario_id)
    SELECT
      v_epi.id,
      'estoque_baixo',
      'Estoque baixo: ' || v_epi.tipo || ' ' || COALESCE(v_epi.marca, '') || ' — ' ||
      v_epi.quantidade_estoque || ' unidade(s) (mínimo: ' || v_epi.quantidade_minima || ')',
      p.id
    FROM perfis p
    WHERE p.funcao IN ('almoxarife', 'admin')
      AND p.ativo = true
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3.7 Função para gerar alertas de empréstimos atrasados
CREATE OR REPLACE FUNCTION gerar_alertas_emprestimos_atrasados()
RETURNS void AS $$
DECLARE
  v_emp RECORD;
BEGIN
  FOR v_emp IN
    SELECT e.id, e.colaborador_id, e.data_prevista_devolucao,
           p.nome as colaborador_nome, ep.tipo, ep.marca
    FROM emprestimos e
    JOIN perfis p ON p.id = e.colaborador_id
    JOIN epis ep ON ep.id = e.epi_id
    WHERE e.status = 'atrasado'
      AND e.data_prevista_devolucao < CURRENT_DATE
  LOOP
    INSERT INTO alertas (epi_id, tipo_alerta, mensagem, destinatario_id)
    SELECT
      v_emp.id,
      'emprestimo_atrasado',
      'Empréstimo atrasado: ' || v_emp.colaborador_nome || ' — ' ||
      v_emp.tipo || ' ' || COALESCE(v_emp.marca, '') || ' (previsto: ' || v_emp.data_prevista_devolucao || ')',
      p.id
    FROM perfis p
    WHERE p.funcao IN ('almoxarife', 'admin')
      AND p.ativo = true
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 4. TRIGGERS
-- ----------------------------------------------------------------------------

-- 4.1 updated_at em perfis
DROP TRIGGER IF EXISTS update_perfis_updated_at ON perfis;
CREATE TRIGGER update_perfis_updated_at
  BEFORE UPDATE ON perfis
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 4.2 updated_at em epis
DROP TRIGGER IF EXISTS update_epis_updated_at ON epis;
CREATE TRIGGER update_epis_updated_at
  BEFORE UPDATE ON epis
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 4.3 updated_at em configuracoes
DROP TRIGGER IF EXISTS update_configuracoes_updated_at ON configuracoes;
CREATE TRIGGER update_configuracoes_updated_at
  BEFORE UPDATE ON configuracoes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 4.4 Auditoria de emprestimos
DROP TRIGGER IF EXISTS trigger_log_emprestimo ON emprestimos;
CREATE TRIGGER trigger_log_emprestimo
  AFTER INSERT OR UPDATE ON emprestimos
  FOR EACH ROW EXECUTE FUNCTION log_movimentacao_emprestimo();

-- ----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------

-- 5.1 Habilitar RLS em todas as tabelas
ALTER TABLE perfis ENABLE ROW LEVEL SECURITY;
ALTER TABLE epis ENABLE ROW LEVEL SECURITY;
ALTER TABLE emprestimos ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracoes ENABLE ROW LEVEL SECURITY;

-- 5.2 Políticas para PERFIS
DROP POLICY IF EXISTS perfis_select ON perfis;
CREATE POLICY perfis_select ON perfis
  FOR SELECT USING (
    ativo = true
    OR auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('admin', 'sst'))
    OR auth.uid() = id
  );

DROP POLICY IF EXISTS perfis_insert ON perfis;
CREATE POLICY perfis_insert ON perfis
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS perfis_update ON perfis;
CREATE POLICY perfis_update ON perfis
  FOR UPDATE USING (
    auth.uid() = id
    OR auth.uid() IN (SELECT id FROM perfis WHERE funcao = 'admin')
  );

DROP POLICY IF EXISTS perfis_delete ON perfis;
CREATE POLICY perfis_delete ON perfis
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao = 'admin')
  );

-- 5.3 Políticas para EPIS
DROP POLICY IF EXISTS epis_select ON epis;
CREATE POLICY epis_select ON epis
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS epis_insert ON epis;
CREATE POLICY epis_insert ON epis
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
  );

DROP POLICY IF EXISTS epis_update ON epis;
CREATE POLICY epis_update ON epis
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
  );

DROP POLICY IF EXISTS epis_delete ON epis;
CREATE POLICY epis_delete ON epis
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao = 'admin')
  );

-- 5.4 Políticas para EMPRESTIMOS
DROP POLICY IF EXISTS emprestimos_select ON emprestimos;
CREATE POLICY emprestimos_select ON emprestimos
  FOR SELECT USING (
    colaborador_id = auth.uid()
    OR auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst'))
  );

DROP POLICY IF EXISTS emprestimos_insert ON emprestimos;
CREATE POLICY emprestimos_insert ON emprestimos
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
    OR colaborador_id = auth.uid()
  );

DROP POLICY IF EXISTS emprestimos_update ON emprestimos;
CREATE POLICY emprestimos_update ON emprestimos
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
    OR colaborador_id = auth.uid()
  );

DROP POLICY IF EXISTS emprestimos_delete ON emprestimos;
CREATE POLICY emprestimos_delete ON emprestimos
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao = 'admin')
  );

-- 5.5 Políticas para MOVIMENTACOES (somente leitura para usuários; escrita via trigger/service)
DROP POLICY IF EXISTS movimentacoes_select ON movimentacoes;
CREATE POLICY movimentacoes_select ON movimentacoes
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS movimentacoes_insert ON movimentacoes;
CREATE POLICY movimentacoes_insert ON movimentacoes
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
  );

-- 5.6 Políticas para ALERTAS
DROP POLICY IF EXISTS alertas_select ON alertas;
CREATE POLICY alertas_select ON alertas
  FOR SELECT USING (
    destinatario_id = auth.uid()
    OR destinatario_id IS NULL
    OR auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst'))
  );

DROP POLICY IF EXISTS alertas_insert ON alertas;
CREATE POLICY alertas_insert ON alertas
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst'))
  );

DROP POLICY IF EXISTS alertas_update ON alertas;
CREATE POLICY alertas_update ON alertas
  FOR UPDATE USING (
    destinatario_id = auth.uid()
    OR auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst'))
  );

DROP POLICY IF EXISTS alertas_delete ON alertas;
CREATE POLICY alertas_delete ON alertas
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
  );

-- 5.7 Políticas para CONFIGURACOES (somente admin pode modificar; todos podem ler)
DROP POLICY IF EXISTS configuracoes_select ON configuracoes;
CREATE POLICY configuracoes_select ON configuracoes
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS configuracoes_modify ON configuracoes;
CREATE POLICY configuracoes_modify ON configuracoes
  FOR ALL USING (
    auth.uid() IN (SELECT id FROM perfis WHERE funcao = 'admin')
  );

-- ----------------------------------------------------------------------------
-- 6. STORAGE BUCKETS
-- ----------------------------------------------------------------------------

-- Criar buckets (executar via SQL Editor ou interface do Supabase)
-- Nota: buckets são criados via API, mas documentamos aqui para referência

/*
-- Via SQL (requer acesso ao schema storage):
INSERT INTO storage.buckets (id, name, public) VALUES
  ('epi-fotos', 'epi-fotos', true),
  ('avatar-fotos', 'avatar-fotos', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage (executar no SQL Editor do Supabase):
CREATE POLICY "epi-fotos-select" ON storage.objects FOR SELECT USING (bucket_id = 'epi-fotos');
CREATE POLICY "epi-fotos-insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'epi-fotos' AND auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
);
CREATE POLICY "epi-fotos-delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'epi-fotos' AND auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
);

CREATE POLICY "avatar-fotos-select" ON storage.objects FOR SELECT USING (bucket_id = 'avatar-fotos');
CREATE POLICY "avatar-fotos-insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'avatar-fotos' AND auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('admin'))
);
CREATE POLICY "avatar-fotos-delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'avatar-fotos' AND auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('admin'))
);
*/

-- ----------------------------------------------------------------------------
-- 7. SEED DE CONFIGURAÇÕES
-- ----------------------------------------------------------------------------
INSERT INTO configuracoes (chave, valor, descricao) VALUES
  ('dias_alerta_validade', '30', 'Dias antes do vencimento para gerar alerta de validade'),
  ('tempo_max_resposta_horas', '24', 'Tempo máximo de resposta do almoxarife em horas úteis'),
  ('quantidade_minima_padrao', '1', 'Quantidade mínima padrão de estoque por EPI'),
  ('versao_sistema', '1.0.0', 'Versão atual do SIGEPI')
ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor, descricao = EXCLUDED.descricao;

-- ----------------------------------------------------------------------------
-- 8. SEED DE DADOS DE TESTE (Opcional — remover em produção)
-- ----------------------------------------------------------------------------

-- Nota: perfis requerem usuários criados via Supabase Auth primeiro.
-- Para teste, crie usuários no Auth UI do Supabase e substitua os UUIDs abaixo
-- pelos IDs reais dos usuários criados.

/*
-- Exemplo de seed (descomente e ajuste os UUIDs após criar usuários no Auth):

INSERT INTO perfis (id, nome, email, matricula, funcao, telefone, ativo) VALUES
  ('uuid-do-admin', 'Carlos Administrador', 'admin@empresa.com', 'ADM001', 'admin', '(11) 99999-0001', true),
  ('uuid-do-almoxarife', 'Maria Almoxarife', 'almoxarife@empresa.com', 'ALM001', 'almoxarife', '(11) 99999-0002', true),
  ('uuid-do-tecnico1', 'João Técnico', 'joao@empresa.com', 'TEC001', 'tecnico_campo', '(11) 99999-0003', true),
  ('uuid-do-tecnico2', 'Ana Técnica', 'ana@empresa.com', 'TEC002', 'tecnico_campo', '(11) 99999-0004', true),
  ('uuid-do-sst', 'Pedro SST', 'sst@empresa.com', 'SST001', 'sst', '(11) 99999-0005', true);

INSERT INTO epis (tipo, marca, modelo, numero_ca, data_fabricacao, data_validade, quantidade_estoque, quantidade_minima, localizacao_fisica, status, ca_validado) VALUES
  ('Capacete', '3M', 'H-700', '12345', '2024-01-15', '2029-01-15', 15, 5, 'Prateleira A1', 'ativo', true),
  ('Luva', 'Ansell', 'HyFlex 11-800', '23456', '2024-03-10', '2026-10-10', 3, 5, 'Prateleira B2', 'ativo', true),
  ('Bota', 'Bracol', 'Bico Aço BA', '34567', '2023-06-20', '2028-06-20', 8, 3, 'Prateleira C1', 'ativo', true),
  ('Oculos', 'Kalipso', 'Veneza', '45678', '2024-02-01', '2026-09-20', 12, 4, 'Prateleira D3', 'ativo', true),
  ('Mascara', '3M', '6200', '56789', '2023-11-05', '2028-11-05', 6, 2, 'Prateleira E1', 'ativo', true),
  ('Protetor Auricular', '3M', 'Peltor X1A', '67890', '2024-05-12', '2029-05-12', 20, 5, 'Prateleira F2', 'ativo', true),
  ('Cinto de Seguranca', 'SteelFlex', 'CG 790E', '78901', '2023-08-30', '2026-08-30', 2, 2, 'Prateleira G1', 'ativo', true),
  ('Luva', 'Mapa', 'Ultrane 553', '89012', '2024-01-20', '2027-01-20', 0, 3, 'Prateleira B3', 'ativo', true),
  ('Capacete', 'Libus', 'L-900', '90123', '2022-04-10', '2025-04-10', 4, 2, 'Prateleira A2', 'vencido', true),
  ('Oculos', 'Danny', 'D-TECH', '01234', '2024-07-15', '2029-07-15', 10, 3, 'Prateleira D1', 'ativo', true);

INSERT INTO emprestimos (epi_id, colaborador_id, almoxarife_id, quantidade, data_emprestimo, data_prevista_devolucao, status, confirmacao_colaborador) VALUES
  ((SELECT id FROM epis WHERE numero_ca = '12345'), 'uuid-do-tecnico1', 'uuid-do-almoxarife', 1, now() - INTERVAL '5 days', CURRENT_DATE + INTERVAL '25 days', 'entregue', true),
  ((SELECT id FROM epis WHERE numero_ca = '23456'), 'uuid-do-tecnico2', 'uuid-do-almoxarife', 1, now() - INTERVAL '40 days', CURRENT_DATE - INTERVAL '10 days', 'atrasado', true),
  ((SELECT id FROM epis WHERE numero_ca = '34567'), 'uuid-do-tecnico1', 'uuid-do-almoxarife', 1, now() - INTERVAL '2 days', CURRENT_DATE + INTERVAL '28 days', 'entregue', false),
  ((SELECT id FROM epis WHERE numero_ca = '45678'), 'uuid-do-tecnico2', 'uuid-do-almoxarife', 1, now() - INTERVAL '1 day', CURRENT_DATE + INTERVAL '29 days', 'pendente', false);
*/

-- ----------------------------------------------------------------------------
-- 9. CRON JOBS (Opcional — requer extensão pg_cron habilitada no Supabase)
-- ----------------------------------------------------------------------------

/*
-- Job diário às 06:00 para atualizar status de EPIs vencidos
SELECT cron.schedule('atualizar-epis-vencidos', '0 6 * * *', 'SELECT atualizar_status_epis_vencidos()');

-- Job diário às 06:05 para verificar empréstimos atrasados
SELECT cron.schedule('verificar-emprestimos-atrasados', '5 6 * * *', 'SELECT verificar_emprestimos_atrasados()');

-- Job diário às 06:10 para gerar alertas de validade
SELECT cron.schedule('gerar-alertas-validade', '10 6 * * *', 'SELECT gerar_alertas_validade()');

-- Job diário às 06:15 para gerar alertas de estoque baixo
SELECT cron.schedule('gerar-alertas-estoque', '15 6 * * *', 'SELECT gerar_alertas_estoque_baixo()');

-- Job diário às 06:20 para gerar alertas de empréstimos atrasados
SELECT cron.schedule('gerar-alertas-atrasados', '20 6 * * *', 'SELECT gerar_alertas_emprestimos_atrasados()');
*/

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================
