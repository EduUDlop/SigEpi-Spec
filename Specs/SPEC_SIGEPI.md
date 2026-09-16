# SPEC TÉCNICA — SIGEPI
## Sistema de Gestão de Equipamentos de Proteção Individual

**Versão:** 1.0  
**Data:** 02/09/2026  
**Stack:** HTML + CSS + JS + Supabase (via CDN)  
**Público-alvo:** Agentes de IA / Desenvolvedores

---

## 1. Visão Geral da Arquitetura

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Navegador     │────▶│   Supabase      │────▶│   PostgreSQL    │
│  (HTML/CSS/JS)  │◄────│  (Auth + REST)  │◄────│   (Dados)       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
       │
       ▼
┌─────────────────┐
│  CDN Libraries  │
│ Alpine.js       │
│ Tailwind CSS    │
│ Supabase JS     │
│ Chart.js        │
│ Phosphor Icons  │
└─────────────────┘
```

**Princípios arquiteturais:**
- **Single Page Application (SPA) leve:** navegação entre "páginas" via troca de views no DOM, sem recarregar o browser.
- **Zero build step:** todas as dependências via CDN. Nenhum `npm install`, `webpack`, `vite` ou `parcel`.
- **Supabase como BaaS:** autenticação, banco de dados, Row Level Security (RLS), Storage e Edge Functions.
- **Mobile-first:** interface responsiva, otimizada para uso no almoxarifado (desktop) e no campo (smartphone).

---

## 2. Stack Tecnológico

| Camada | Tecnologia | Versão / CDN | Propósito |
|---|---|---|---|
| **UI Framework** | Alpine.js | `https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js` | Reatividade leve, binding de dados, eventos, sem build |
| **CSS Framework** | Tailwind CSS | `https://cdn.tailwindcss.com` | Utility-first, responsivo, dark mode opcional |
| **Backend/DB** | Supabase JS Client | `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.x.x` | Auth, queries, realtime, storage |
| **Gráficos** | Chart.js | `https://cdn.jsdelivr.net/npm/chart.js@4.x.x` | Dashboard com gráficos de estoque e movimentação |
| **Ícones** | Phosphor Icons | `https://unpkg.com/@phosphor-icons/web` | Ícones consistentes, leves, SVG |
| **Datas** | date-fns (ESM) | `https://cdn.jsdelivr.net/npm/date-fns@3.x.x/+esm` | Manipulação e formatação de datas (validade, empréstimos) |
| **QR Code** | qrcode.js | `https://cdn.jsdelivr.net/npm/qrcode@1.x.x/build/qrcode.min.js` | Geração de QR Code para identificação física de EPIs |
| **Notificações** | Toastify JS | `https://cdn.jsdelivr.net/npm/toastify-js` | Feedback visual (sucesso, erro, alerta) |
| **Impressão** | Print.js | `https://cdn.jsdelivr.net/npm/print-js@1.x.x` | Impressão de relatórios e etiquetas |

> **Nota sobre dependências:** Todas as bibliotecas são carregadas via CDN com `defer` ou `type="module"`. Não há `package.json`, `node_modules` ou bundler. O projeto é um conjunto de arquivos estáticos servidos por qual servidor web (nginx, Apache, Vercel, Netlify, GitHub Pages).

---

## 3. Configuração do Supabase

### 3.1. Variáveis de Ambiente (frontend)

Criar arquivo `config.js`:

```javascript
// config.js
const SUPABASE_URL = 'https://<seu-projeto>.supabase.co';
const SUPABASE_ANON_KEY = '<sua-anon-key>';

export { SUPABASE_URL, SUPABASE_ANON_KEY };
```

> Este arquivo NÃO deve ser versionado em repositórios públicos. Em produção, use variáveis de ambiente injetadas no build ou substitua manualmente.

### 3.2. Inicialização do Cliente

```javascript
// supabase-client.js
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.47.0/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

---

## 4. Modelo de Dados (PostgreSQL)

### 4.1. Tabelas

#### `perfis` (extensão da auth do Supabase)
```sql
CREATE TABLE perfis (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  nome TEXT NOT NULL,
  email TEXT NOT NULL,
  matricula TEXT UNIQUE,
  funcao TEXT CHECK (funcao IN ('almoxarife', 'tecnico_campo', 'sst', 'admin', 'gestor')),
  telefone TEXT,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### `epis`
```sql
CREATE TABLE epis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  status TEXT CHECK (status IN ('ativo', 'vencido', 'baixado', 'em_uso')) DEFAULT 'ativo',
  ca_validado BOOLEAN DEFAULT false,
  ca_validado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### `emprestimos`
```sql
CREATE TABLE emprestimos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  epi_id UUID REFERENCES epis(id) NOT NULL,
  colaborador_id UUID REFERENCES perfis(id) NOT NULL,
  almoxarife_id UUID REFERENCES perfis(id) NOT NULL,
  quantidade INTEGER NOT NULL DEFAULT 1,
  data_emprestimo TIMESTAMPTZ DEFAULT now(),
  data_prevista_devolucao DATE,
  data_devolucao TIMESTAMPTZ,
  status TEXT CHECK (status IN ('pendente', 'entregue', 'devolvido', 'trocado', 'atrasado')) DEFAULT 'pendente',
  motivo_troca TEXT,
  observacao TEXT,
  confirmacao_colaborador BOOLEAN DEFAULT false,
  confirmacao_colaborador_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### `movimentacoes` (log de auditoria)
```sql
CREATE TABLE movimentacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  epi_id UUID REFERENCES epis(id) NOT NULL,
  tipo_movimentacao TEXT CHECK (tipo_movimentacao IN ('entrada', 'saida', 'devolucao', 'troca', 'baixa', 'ajuste')) NOT NULL,
  quantidade INTEGER NOT NULL,
  quantidade_anterior INTEGER NOT NULL,
  quantidade_nova INTEGER NOT NULL,
  responsavel_id UUID REFERENCES perfis(id) NOT NULL,
  colaborador_id UUID REFERENCES perfis(id),
  emprestimo_id UUID REFERENCES emprestimos(id),
  observacao TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### `alertas`
```sql
CREATE TABLE alertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  epi_id UUID REFERENCES epis(id),
  tipo_alerta TEXT CHECK (tipo_alerta IN ('validade_30_dias', 'validade_7_dias', 'validade_vencida', 'estoque_baixo', 'emprestimo_atrasado')) NOT NULL,
  mensagem TEXT NOT NULL,
  lido BOOLEAN DEFAULT false,
  destinatario_id UUID REFERENCES perfis(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### `configuracoes` (parametrização do sistema)
```sql
CREATE TABLE configuracoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chave TEXT UNIQUE NOT NULL,
  valor TEXT NOT NULL,
  descricao TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed inicial
INSERT INTO configuracoes (chave, valor, descricao) VALUES
  ('dias_alerta_validade', '30', 'Dias antes do vencimento para alertar'),
  ('tempo_max_resposta_horas', '24', 'Tempo máximo de resposta do almoxarife em horas'),
  ('quantidade_minima_padrao', '1', 'Quantidade mínima padrão de estoque por EPI');
```

### 4.2. Índices Recomendados

```sql
CREATE INDEX idx_epis_status ON epis(status);
CREATE INDEX idx_epis_data_validade ON epis(data_validade);
CREATE INDEX idx_emprestimos_status ON emprestimos(status);
CREATE INDEX idx_emprestimos_colaborador ON emprestimos(colaborador_id);
CREATE INDEX idx_emprestimos_epi ON emprestimos(epi_id);
CREATE INDEX idx_alertas_lido ON alertas(lido);
CREATE INDEX idx_movimentacoes_epi ON movimentacoes(epi_id);
CREATE INDEX idx_movimentacoes_created ON movimentacoes(created_at);
```

### 4.3. Triggers

#### Atualização automática de `updated_at`
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_epis_updated_at BEFORE UPDATE ON epis
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Trigger de movimentação (auditoria automática)
```sql
CREATE OR REPLACE FUNCTION log_movimentacao_emprestimo()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'entregue' THEN
    INSERT INTO movimentacoes (epi_id, tipo_movimentacao, quantidade, quantidade_anterior, quantidade_nova, responsavel_id, colaborador_id, emprestimo_id, observacao)
    SELECT NEW.epi_id, 'saida', NEW.quantidade, e.quantidade_estoque, e.quantidade_estoque - NEW.quantidade, NEW.almoxarife_id, NEW.colaborador_id, NEW.id, 'Empréstimo registrado'
    FROM epis e WHERE e.id = NEW.epi_id;

    UPDATE epis SET quantidade_estoque = quantidade_estoque - NEW.quantidade WHERE id = NEW.epi_id;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status != 'devolvido' AND NEW.status = 'devolvido' THEN
    INSERT INTO movimentacoes (epi_id, tipo_movimentacao, quantidade, quantidade_anterior, quantidade_nova, responsavel_id, colaborador_id, emprestimo_id, observacao)
    SELECT NEW.epi_id, 'devolucao', NEW.quantidade, e.quantidade_estoque, e.quantidade_estoque + NEW.quantidade, NEW.almoxarife_id, NEW.colaborador_id, NEW.id, 'Devolução registrada'
    FROM epis e WHERE e.id = NEW.epi_id;

    UPDATE epis SET quantidade_estoque = quantidade_estoque + NEW.quantidade WHERE id = NEW.epi_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_log_emprestimo AFTER INSERT OR UPDATE ON emprestimos
  FOR EACH ROW EXECUTE FUNCTION log_movimentacao_emprestimo();
```

---

## 5. Row Level Security (RLS) — Políticas de Acesso

### 5.1. Habilitar RLS em todas as tabelas

```sql
ALTER TABLE perfis ENABLE ROW LEVEL SECURITY;
ALTER TABLE epis ENABLE ROW LEVEL SECURITY;
ALTER TABLE emprestimos ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracoes ENABLE ROW LEVEL SECURITY;
```

### 5.2. Políticas

```sql
-- perfis: todos veem perfis ativos; admin/SST veem todos
CREATE POLICY "perfis_select" ON perfis FOR SELECT USING (ativo = true OR auth.uid() IN (
  SELECT id FROM perfis WHERE funcao IN ('admin', 'sst')
));
CREATE POLICY "perfis_admin" ON perfis FOR ALL USING (
  auth.uid() IN (SELECT id FROM perfis WHERE funcao = 'admin')
);

-- epis: todos autenticados podem ler; almoxarife/admin podem modificar
CREATE POLICY "epis_select" ON epis FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "epis_modify" ON epis FOR ALL USING (
  auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
);

-- emprestimos: colaborador vê os seus; almoxarife vê todos
CREATE POLICY "emprestimos_select" ON emprestimos FOR SELECT USING (
  colaborador_id = auth.uid() OR 
  auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst'))
);
CREATE POLICY "emprestimos_insert" ON emprestimos FOR INSERT WITH CHECK (
  auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin')) OR
  colaborador_id = auth.uid()
);
CREATE POLICY "emprestimos_update" ON emprestimos FOR UPDATE USING (
  auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin')) OR
  colaborador_id = auth.uid()
);

-- movimentacoes: somente leitura para usuários autenticados; escrita via trigger/service
CREATE POLICY "movimentacoes_select" ON movimentacoes FOR SELECT USING (auth.role() = 'authenticated');

-- alertas: usuário vê seus próprios alertas; admin/almoxarife vê todos
CREATE POLICY "alertas_select" ON alertas FOR SELECT USING (
  destinatario_id = auth.uid() OR 
  auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst')) OR
  destinatario_id IS NULL
);
CREATE POLICY "alertas_update" ON alertas FOR UPDATE USING (
  destinatario_id = auth.uid() OR 
  auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin', 'sst'))
);
```

---

## 6. Supabase Edge Functions (Opcional, mas recomendado)

### 6.1. `validar-ca` — Validação automática do Certificado de Aprovação

```typescript
// supabase/functions/validar-ca/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { numero_ca } = await req.json()

  // Consulta API pública do Ministério do Trabalho (ou fallback para base interna)
  // Nota: implementar cache para evitar rate limiting

  const valido = await validarCA(numero_ca) // implementação específica

  return new Response(JSON.stringify({ valido, numero_ca }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### 6.2. `gerar-alertas` — Job diário de alertas de validade

```typescript
// supabase/functions/gerar-alertas/index.ts
// Executado via cron (pg_cron ou scheduler externo)
// Verifica EPIs com validade em 30, 7 dias e vencidos
// Insere registros na tabela alertas
```

---

## 7. Estrutura de Arquivos do Projeto

```
sigepi/
├── index.html                    # Ponto de entrada, layout base, router
├── config.js                     # Variáveis de ambiente (Supabase)
├── supabase-client.js            # Cliente Supabase inicializado
├── app.js                        # Inicialização Alpine.js, router, guards
│
├── css/
│   └── custom.css                # Estilos customizados além do Tailwind
│
├── components/                   # Componentes reutilizáveis (Alpine.js)
│   ├── navbar.html               # Barra de navegação com menu por perfil
│   ├── sidebar.html              # Menu lateral (desktop)
│   ├── modal.html                # Modal genérico
│   ├── toast.html                # Notificações Toastify
│   ├── data-table.html           # Tabela com paginação, busca, ordenação
│   ├── epi-card.html             # Card de EPI para listagem
│   ├── emprestimo-card.html      # Card de empréstimo
│   ├── qr-scanner.html           # Leitor de QR Code para retirada/devolução
│   └── chart-container.html      # Container para gráficos Chart.js
│
├── pages/                        # Views/páginas da SPA
│   ├── login.html                # Autenticação (email/senha + magic link)
│   ├── dashboard.html            # Painel principal (KPIs, gráficos, alertas)
│   ├── epis/
│   │   ├── listar.html           # Listagem com filtros e busca
│   │   ├── cadastrar.html        # Formulário de cadastro/edição
│   │   └── detalhe.html          # Ficha completa do EPI + histórico
│   ├── emprestimos/
│   │   ├── listar.html           # Todos os empréstimos
│   │   ├── solicitar.html        # Tela do colaborador solicitar EPI
│   │   ├── liberar.html          # Tela do almoxarife liberar
│   │   └── minhas-solicitacoes.html # Visão do colaborador
│   ├── trocas/
│   │   ├── solicitar.html        # Solicitação de troca
│   │   └── processar.html        # Almoxarife processa troca/devolução
│   ├── relatorios/
│   │   ├── estoque.html          # Relatório de posição de estoque
│   │   ├── movimentacoes.html    # Relatório de auditoria
│   │   ├── validade.html         # Relatório de EPIs próximos ao vencimento
│   │   └── conformidade.html     # Relatório NR-06
│   ├── alertas/
│   │   └── central.html          # Central de notificações
│   ├── usuarios/
│   │   ├── listar.html           # Gestão de usuários (admin)
│   │   └── perfil.html           # Meu perfil
│   └── configuracoes/
│       └── sistema.html          # Parametrização (admin)
│
├── services/                     # Camada de abstração do Supabase
│   ├── auth.service.js           # Login, logout, registro, recuperação senha
│   ├── epi.service.js            # CRUD + busca + filtros
│   ├── emprestimo.service.js     # CRUD + fluxo completo
│   ├── movimentacao.service.js   # Auditoria + relatórios
│   ├── alerta.service.js         # CRUD + marcar como lido
│   ├── dashboard.service.js      # Queries agregadas (KPIs)
│   └── config.service.js         # Parametrização
│
├── stores/                       # Estado global (Alpine.js stores)
│   ├── auth.store.js             # Usuário logado, permissões
│   ├── app.store.js              # Estado da app (tema, sidebar, loading)
│   └── notificacao.store.js      # Contador de alertas não lidos
│
├── utils/
│   ├── date.js                   # Helpers de data (formatar, calcular dias, validade)
│   ├── validators.js             # Validação de formulários (CA, CPF, email)
│   ├── formatters.js             # Máscaras (telefone, data, número)
│   ├── qr-code.js                # Geração e leitura de QR Code
│   ├── pdf-generator.js          # Geração de relatórios em PDF (jsPDF)
│   └── constants.js              # Enums, mensagens padrão, rotas
│
└── assets/
    ├── logo.svg                  # Logo da empresa
    └── favicon.ico
```

---

## 8. Requisitos Técnicos Detalhados

### 8.1. Autenticação e Autorização

- **RF-Auth-01:** Login via email + senha (Supabase Auth).
- **RF-Auth-02:** Magic link (link mágico) como alternativa para técnicos de campo.
- **RF-Auth-03:** Recuperação de senha por email.
- **RF-Auth-04:** Após login, o sistema deve buscar o perfil do usuário em `perfis` e armazenar no `auth.store.js`.
- **RF-Auth-05:** Redirecionamento pós-login baseado no `funcao`: `almoxarife` → dashboard, `tecnico_campo` → solicitar EPI.
- **RF-Auth-06:** Guardas de rota: páginas de admin só acessíveis por `funcao = 'admin'`; páginas do almoxarife por `funcao IN ('almoxarife', 'admin')`.
- **RF-Auth-07:** Sessão persistente via `supabase.auth.onAuthStateChange`.

### 8.2. Módulo de EPIs

- **RF-EPI-01:** Cadastro com validação em tempo real do número do CA (chamada Edge Function `validar-ca` ou consulta à base interna).
- **RF-EPI-02:** Upload de foto do EPI via Supabase Storage (bucket `epi-fotos`, política RLS por usuário autenticado).
- **RF-EPI-03:** Geração automática de QR Code ao cadastrar, exibido na ficha do EPI e possibilitando impressão de etiqueta.
- **RF-EPI-04:** Status automático: `ativo` (em estoque), `em_uso` (emprestado), `vencido` (data_validade < hoje), `baixado` (quantidade = 0 ou baixa manual).
- **RF-EPI-05:** Filtros na listagem: tipo, marca, status, validade (próximos a vencer, vencidos), localização.
- **RF-EPI-06:** Busca full-text por tipo, marca, modelo, número CA.
- **RF-EPI-07:** Histórico de movimentações visível na ficha do EPI (últimas 50, com paginação).

### 8.3. Módulo de Empréstimos

- **RF-Emp-01:** Colaborador solicita EPI informando tipo. O sistema sugere EPIs disponíveis do tipo solicitado.
- **RF-Emp-02:** Notificação em tempo real ao almoxarife via Supabase Realtime (subscription na tabela `emprestimos`).
- **RF-Emp-03:** Almoxarife visualiza fila de solicitações pendentes com prioridade por data.
- **RF-Emp-04:** Liberação com verificação automática: EPI disponível? Validade OK? Quantidade suficiente?
- **RF-Emp-05:** Bloqueio de saída de EPIs vencidos ou com estoque zero (RF02 do TAP).
- **RF-Emp-06:** Confirmação de recebimento pelo colaborador (assinatura digital simplificada: checkbox + timestamp).
- **RF-Emp-07:** Devolução: almoxarife escaneia QR Code do EPI ou busca pelo empréstimo ativo. Registra estado do EPI (bom, danificado, inservível).
- **RF-Emp-08:** Empréstimos atrasados (data_prevista_devolucao < hoje AND status = 'entregue') destacados em vermelho.

### 8.4. Módulo de Trocas

- **RF-Troca-01:** Colaborador solicita troca informando motivo: vencimento, danificação, perda, inadequação.
- **RF-Troca-02:** Se motivo = vencimento, o sistema sugere automaticamente a troca do mesmo tipo de EPI.
- **RF-Troca-03:** Almoxarife inspeciona o EPI devolvido e classifica: reutilizável (retorna ao estoque), descarte (baixa), danificado (baixa parcial).
- **RF-Troca-04:** Baixa automática de EPIs irrecuperáveis (atualiza `quantidade_estoque` e registra movimentação tipo `baixa`).

### 8.5. Alertas e Notificações

- **RF-Alerta-01:** Alertas automáticos gerados via trigger PostgreSQL ou Edge Function cron:
  - 30 dias antes do vencimento do EPI (para almoxarife e SST);
  - 7 dias antes do vencimento (para colaborador com EPI emprestado);
  - No dia do vencimento (para todos);
  - Estoque abaixo da quantidade mínima;
  - Empréstimo atrasado.
- **RF-Alerta-02:** Badge de notificações não lidas no navbar, atualizado em tempo real via Realtime.
- **RF-Alerta-03:** Marcar alerta como lido (atualiza `lido = true`).
- **RF-Alerta-04:** Alertas visuais na dashboard: cards coloridos (amarelo: 30 dias, laranja: 7 dias, vermelho: vencido/estoque baixo).

### 8.6. Dashboard

- **RF-Dash-01:** KPIs em cards: total de EPIs em estoque, EPIs vencidos, empréstimos pendentes, empréstimos atrasados, alertas não lidos.
- **RF-Dash-02:** Gráfico de barras: movimentações por tipo (entrada/saída/devolução) nos últimos 30 dias.
- **RF-Dash-03:** Gráfico de pizza/donut: distribuição de EPIs por status.
- **RF-Dash-04:** Gráfico de linha: evolução de empréstimos ao longo do tempo.
- **RF-Dash-05:** Tabela rápida: top 5 EPIs com estoque mais crítico.
- **RF-Dash-06:** Atualização automática a cada 30 segundos ou via Realtime.

### 8.7. Relatórios

- **RF-Rel-01:** Relatório de estoque: lista todos os EPIs com quantidade, localização, validade, status. Exportável PDF/Excel.
- **RF-Rel-02:** Relatório de movimentações: filtro por período, tipo, responsável, EPI. Exportável PDF/Excel.
- **RF-Rel-03:** Relatório de validade: EPIs vencidos e próximos ao vencimento. Exportável PDF/Excel.
- **RF-Rel-04:** Relatório de conformidade NR-06: EPIs por colaborador, datas de empréstimo, validade, status. Exportável PDF.
- **RF-Rel-05:** Todos os relatórios devem ter cabeçalho com logo da empresa, data de geração e paginação.

### 8.8. Configurações do Sistema

- **RF-Config-01:** Edição dos parâmetros da tabela `configuracoes` (apenas admin).
- **RF-Config-02:** Possibilidade de ajustar dias de alerta de validade, tempo máximo de resposta, quantidade mínima padrão.

---

## 9. Interface do Usuário (UI/UX)

### 9.1. Design System

- **Framework:** Tailwind CSS via CDN com configuração customizada.
- **Cores:**
  - Primária: `slate-900` (textos, headers)
  - Secundária: `slate-500` (metadados, ícones secundários)
  - Acento: `blue-600` (botões primários, links, gráficos)
  - Sucesso: `emerald-500` (status positivos, confirmações)
  - Alerta: `amber-500` (alertas, atenção)
  - Perigo: `red-500` (erros, vencidos, atrasados, estoque crítico)
  - Fundo: `slate-50` (page background), `white` (cards)
- **Tipografia:** Sistema nativo (`font-sans`). Títulos: semibold. Dados: tabular-nums para números.
- **Bordas e sombras:** bordas sutis (`border-slate-200`), sombras leves (`shadow-sm`, `shadow-md` em cards elevados).
- **Radii:** `rounded-lg` (8px) para cards, `rounded-md` (6px) para inputs, `rounded-full` para avatares/badges.

### 9.2. Telas Principais

#### Login
- Card centralizado, max-width 400px.
- Campos: email, senha, checkbox "lembrar-me".
- Botão "Entrar" + link "Esqueci minha senha".
- Link alternativo: "Entrar com link mágico" (magic link).

#### Dashboard (Almoxarife / Admin / SST)
- Layout: sidebar fixa (desktop) / bottom nav (mobile) + conteúdo principal.
- Grid de KPIs: 4 cards na linha superior (desktop), 2x2 (mobile).
- Gráficos: 2 por linha (desktop), empilhados (mobile).
- Tabela rápida: estoque crítico.
- Lista de alertas recentes (máx. 5).

#### Listagem de EPIs
- Toolbar: busca (full-text), filtros (dropdowns), botão "Novo EPI".
- Tabela desktop / Cards mobile.
- Colunas: foto miniatura, tipo, marca, modelo, CA, validade, estoque, status (badge colorido), ações (editar, ver, QR).
- Paginação: 20 itens por página.

#### Cadastro de EPI
- Formulário em duas colunas (desktop), uma coluna (mobile).
- Campos: tipo (select), marca, modelo, número CA (com botão "Validar CA"), datas (date picker), quantidade, localização, foto (drag & drop ou input file), preview da imagem.
- Validação em tempo real: CA obrigatório, validade > fabricação, quantidade >= 0.
- Botões: "Salvar", "Salvar e cadastrar outro", "Cancelar".

#### Solicitação de EPI (Colaborador)
- Tela simplificada, mobile-first.
- Select do tipo de EPI (busca inteligente).
- Preview do EPI sugerido (foto, validade, disponibilidade).
- Botão "Solicitar".
- Lista "Minhas solicitações" abaixo do formulário.

#### Liberação de Empréstimo (Almoxarife)
- Fila de solicitações pendentes (cards ou tabela).
- Cada item: colaborador, tipo solicitado, data/hora da solicitação, tempo decorrido.
- Ação rápida: "Liberar" (abre modal com seleção do EPI específico) / "Recusar" (com motivo).
- Após liberação: QR Code gerado para o colaborador escanear na retirada.

#### Processamento de Troca/Devolução
- Leitor de QR Code (câmera do dispositivo) ou busca por matrícula/colaborador.
- Exibe EPIs emprestados ativos do colaborador.
- Para cada EPI: botões "Devolver" (bom estado) / "Trocar" (seleciona motivo) / "Baixar" (danificado).
- Modal de confirmação com resumo da operação.

### 9.3. Responsividade

- **Mobile (< 768px):** navegação inferior (bottom nav), cards empilhados, formulários em coluna única, tabelas convertidas em cards.
- **Tablet (768px - 1024px):** sidebar colapsável, grids de 2 colunas.
- **Desktop (> 1024px):** sidebar expandida, grids de 3-4 colunas, tabelas completas.

### 9.4. Estados e Feedback

- **Loading:** skeleton screens em cards e tabelas; spinner em botões de ação.
- **Sucesso:** Toastify verde, auto-dismiss em 3s.
- **Erro:** Toastify vermelho, persistente até fechar, com mensagem clara.
- **Alerta:** Toastify amarelo.
- **Empty state:** ilustração simplificada + mensagem orientadora + CTA (ex: "Cadastrar primeiro EPI").
- **Offline:** banner discreto indicando modo offline (dados em cache local, sincronização ao reconectar).

---

## 10. Fluxos de Dados (Data Flow)

### 10.1. Cadastro de EPI

```
Usuário (almoxarife)
  ↓ preenche formulário
Componente cadastrar.html (Alpine.js)
  ↓ validação client-side (validators.js)
  ↓ upload foto → Supabase Storage (bucket epi-fotos)
  ↓ obtém publicUrl da foto
  ↓ INSERT INTO epis (dados + foto_url)
Supabase (RLS: almoxarife/admin)
  ↓ trigger: verifica se CA já existe
  ↓ retorna registro criado
Frontend
  ↓ exibe toast de sucesso
  ↓ redireciona para listagem ou cadastra outro
  ↓ gera QR Code do novo EPI (qrcode.js)
```

### 10.2. Solicitação e Liberação de Empréstimo

```
Colaborador
  ↓ acessa "Solicitar EPI"
  ↓ seleciona tipo
Frontend
  ↓ busca EPIs disponíveis do tipo (SELECT * FROM epis WHERE tipo = X AND status = 'ativo' AND quantidade_estoque > 0)
  ↓ exibe sugestões
  ↓ colaborador confirma
  ↓ INSERT INTO emprestimos (epi_id, colaborador_id, status='pendente')
Supabase Realtime
  ↓ notifica almoxarife (subscription na tabela emprestimos)
Almoxarife
  ↓ visualiza na fila
  ↓ seleciona EPI específico, verifica validade
  ↓ UPDATE emprestimos SET status='entregue', almoxarife_id=X
Supabase Trigger
  ↓ log_movimentacao_emprestimo: INSERT movimentacoes + UPDATE epis quantidade_estoque
Frontend (colaborador)
  ↓ recebe notificação: "Seu EPI foi liberado"
  ↓ confirma recebimento: UPDATE emprestimos SET confirmacao_colaborador=true
```

### 10.3. Alerta de Validade

```
Cron job (Edge Function ou pg_cron)
  ↓ roda diariamente às 06:00
  ↓ SELECT * FROM epis WHERE data_validade <= CURRENT_DATE + INTERVAL '30 days'
  ↓ para cada EPI vencido/próximo:
      INSERT INTO alertas (epi_id, tipo_alerta, mensagem, destinatario_id)
      -- destinatário = almoxarife (alertas gerais) ou colaborador (se emprestado)
Supabase Realtime
  ↓ notifica usuários conectados
Frontend
  ↓ incrementa badge de notificações
  ↓ exibe alerta na dashboard
```

---

## 11. Supabase Storage

### 11.1. Buckets

```sql
-- Bucket para fotos dos EPIs
INSERT INTO storage.buckets (id, name, public) VALUES ('epi-fotos', 'epi-fotos', true);

-- Políticas de acesso
CREATE POLICY "epi-fotos-select" ON storage.objects FOR SELECT USING (bucket_id = 'epi-fotos');
CREATE POLICY "epi-fotos-insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'epi-fotos' AND auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
);
CREATE POLICY "epi-fotos-delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'epi-fotos' AND auth.uid() IN (SELECT id FROM perfis WHERE funcao IN ('almoxarife', 'admin'))
);
```

### 11.2. Convenção de Nomes

```
epi-fotos/{epi_id}/{timestamp}_{nome_original}.jpg
```

---

## 12. Supabase Realtime

### 12.1. Subscriptions Obrigatórias

```javascript
// No app.js ou auth.store.js
// 1. Notificações de novos empréstimos (almoxarife)
supabase
  .channel('emprestimos-pendentes')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'emprestimos', filter: 'status=eq.pendente' }, callback)
  .subscribe();

// 2. Atualização de status de empréstimo (colaborador)
supabase
  .channel('meus-emprestimos')
  .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'emprestimos', filter: `colaborador_id=eq.${userId}` }, callback)
  .subscribe();

// 3. Novos alertas
supabase
  .channel('meus-alertas')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'alertas', filter: `destinatario_id=eq.${userId}` }, callback)
  .subscribe();

// 4. Mudanças no estoque (dashboard)
supabase
  .channel('estoque-alteracoes')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'epis' }, callback)
  .subscribe();
```

---

## 13. Performance e Otimização

- **Paginação:** todas as listagens usam `range()` do Supabase (limit + offset). Nunca carregar mais de 50 registros de uma vez.
- **Cache local:** usar `localStorage` ou `IndexedDB` para cache de dados estáticos (tipos de EPI, configurações). Dados dinâmicos (estoque, empréstimos) sempre buscam do servidor.
- **Lazy loading:** imagens de EPIs com `loading="lazy"`.
- **Debounce:** campos de busca com debounce de 300ms para evitar queries excessivas.
- **Otimização de queries:** usar `.select()` com colunas específicas, evitar `select(*)` em tabelas grandes.
- **Supabase Realtime:** desinscrever canais ao sair da página ( Alpine.js `$cleanup` ou `beforeDestroy`).

---

## 14. Segurança

- **RLS:** todas as tabelas com RLS habilitado. Nenhuma query sem política.
- **Validação client + server:** validar formulários no frontend (UX) E no backend (RLS/políticas/triggers).
- **Sanitização:** nunca renderizar HTML dinâmico sem sanitização. Usar `textContent` em vez de `innerHTML` para dados do usuário.
- **Senhas:** mínimo 8 caracteres, 1 maiúscula, 1 número (validação client-side; Supabase Auth já aplica regras).
- **LGPD:** consentimento explícito no cadastro; possibilidade de exportar dados pessoais; exclusão lógica (soft delete via `ativo = false`).
- **HTTPS:** obrigatório em produção (Supabase já fornece).
- **CSP:** configurar Content-Security-Policy para permitir apenas CDNs confiáveis.

---

## 15. Testes (Estratégia)

Como não há framework de teste no stack, adotar:

- **Testes manuais guiados:** checklist de cenários por módulo (login, cadastro EPI, empréstimo completo, troca, alertas, relatórios).
- **Testes de integração via console:** scripts JavaScript no navegador para validar queries Supabase, RLS e triggers.
- **Testes de usabilidade:** validação com almoxarife e 2-3 técnicos de campo antes do go-live.

---

## 16. Deploy e Hospedagem

### 16.1. Opções Recomendadas

1. **Vercel / Netlify:** deploy automático a partir do GitHub. Ideal para SPA estática.
2. **GitHub Pages:** gratuito, simples, sem CI/CD avançado.
3. **Servidor próprio (nginx):** upload dos arquivos estáticos para `/var/www/sigepi/`.

### 16.2. Configuração de Produção

- Definir `config.js` com credenciais de produção do Supabase.
- Configurar CORS no Supabase para o domínio de produção.
- Ativar autenticação de 2 fatores (2FA) para usuários admin no Supabase Auth.
- Configurar backup automático do banco PostgreSQL (Supabase já faz, mas verificar retenção).

---

## 17. Critérios de Aceitação Técnica

Antes de considerar o sistema pronto para produção, o agente de IA deve garantir:

- [ ] Todas as 8 RFs do TAP estão implementadas e testadas.
- [ ] RLS está habilitado em 100% das tabelas com políticas adequadas.
- [ ] Autenticação funciona (login, logout, recuperação de senha, magic link).
- [ ] Dashboard exibe dados reais do Supabase (não mockados).
- [ ] Alertas de validade são gerados automaticamente e exibidos corretamente.
- [ ] QR Code é gerado no cadastro do EPI e legível na leitura de devolução/troca.
- [ ] Relatórios são exportáveis em PDF e Excel.
- [ ] Interface é responsiva e funcional em smartphone (testar em iOS e Android).
- [ ] Não há erros no console do navegador (exceções de JavaScript).
- [ ] Tempo de carregamento inicial < 3s em conexão 4G.
- [ ] Documentação de deploy está clara (README com instruções passo a passo).

---

## 18. Glossário

| Termo | Definição |
|---|---|
| **EPI** | Equipamento de Proteção Individual |
| **CA** | Certificado de Aprovação do Ministério do Trabalho |
| **NR-06** | Norma Regulamentadora nº 6 — EPIs |
| **SST** | Segurança e Saúde no Trabalho |
| **RLS** | Row Level Security — segurança em nível de linha do PostgreSQL |
| **SPA** | Single Page Application |
| **BaaS** | Backend as a Service |
| **Go-live** | Data de implantação em produção |

---

## 19. Referências

- [Supabase Documentation](https://supabase.com/docs)
- [Alpine.js Documentation](https://alpinejs.dev/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Chart.js Documentation](https://www.chartjs.org/)
- [NR-06 — EPIs (MTE)](https://www.gov.br/trabalho-e-emprego/pt-br/acesso-a-informacao/perguntas-frequentes/normas-regulamentadoras/nr-06)
- [PMBOK 7th Edition — Project Charter](https://www.pmi.org/pmbok-guide-standards)

---

*Documento gerado em 02/09/2026. Revisar e aprovar antes do início do desenvolvimento.*
