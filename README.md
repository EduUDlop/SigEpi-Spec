# SIGEPI — Sistema de Gestão de Equipamentos de Proteção Individual

> **Conformidade NR-06 • Automação de Almoxarifado • Sincronização com MTE e Supabase**

O **SIGEPI** é uma Single Page Application (SPA) moderna, leve e responsiva projetada para a gestão completa de EPIs, controle de estoque, solicitações de campo, liberações ágeis com leitor de QR Code/Código de Barras no balcão e auditoria contínua de conformidade normativa.

---

## 🚀 Tecnologias e Arquitetura

O projeto adota uma arquitetura **Zero Build Step** (sem `npm`, `webpack` ou bundlers), permitindo que todos os arquivos estáticos sejam servidos diretamente por qualquer servidor web (Nginx, Vercel, Netlify, Apache ou Python HTTP Server).

- **UI & Reatividade:** [Alpine.js 3.x](https://alpinejs.dev/) (via CDN)
- **Estilização:** [Tailwind CSS](https://tailwindcss.com/) (via CDN com design system do Google Stitch)
- **Backend as a Service (BaaS):** [Supabase](https://supabase.com/) (PostgreSQL + Auth + Realtime + RLS)
- **Gráficos:** [Chart.js 4.x](https://www.chartjs.org/)
- **Notificações:** [Toastify JS](https://apvarun.github.io/toastify-js/)
- **Ícones & Tipografia:** Material Symbols Outlined, Poppins & Open Sans

---

## 📁 Estrutura de Arquivos

```
/
├── index.html                  # Layout base da SPA (Sidebar, Header e Router)
├── config.js                   # Credenciais de conexão com Supabase
├── supabase-client.js          # Cliente Supabase inicializado via CDN ESM
├── app.js                      # Controlador principal e roteador das páginas
├── realtime.service.js         # Subscriptions do Supabase Realtime
│
├── pages/                      # Views HTML dinamizadas pela SPA
│   ├── login.html              # Autenticação de usuários
│   ├── dashboard.html          # Painel principal (KPIs, gráficos e alertas NR-06)
│   ├── catalogo-estoque.html   # Tabela de EPIs e Ficha Técnica detalhada
│   ├── solicitacoes.html       # Formulário de solicitação de EPI pelo colaborador
│   ├── liberacoes-scanner.html # Módulo de balcão com leitor óptico e atalho F2
│   └── relatorios.html         # Emissão de Fichas NR-06 e laudos
│
├── services/                   # Camada de integração de dados e Supabase
│   ├── auth.service.js         # Autenticação e perfil
│   ├── epi.service.js          # CRUD, filtros e busca de EPIs
│   ├── emprestimo.service.js   # Solicitações, liberações e devoluções
│   ├── alerta.service.js       # Gerenciamento de alertas de validade
│   └── dashboard.service.js    # Agregação de métricas em tempo real
│
├── stores/                     # Estado global gerenciado pelo Alpine.js
│   ├── auth.store.js           # Estado de login e perfil do usuário
│   ├── app.store.js            # Roteamento e navegação
│   └── notificacao.store.js    # Contador de alertas e acionamento de Toasts
│
├── Specs/                      # Especificações do projeto e Esquema SQL
│   ├── sigepi_schema.sql       # Script DDL com tabelas, RLS e triggers
│   └── SPEC_SIGEPI.md          # Especificação técnica detalhada
│
└── Theme/                      # Telas e protótipos originais do Google Stitch
```

---

## ⚡ Como Executar o Projeto Localmente

Como a aplicação é 100% estática, basta executar qualquer servidor HTTP na raiz do repositório:

### Utilizando Python:
```bash
python3 -m http.server 8000
```
Em seguida, acesse no seu navegador: **`http://localhost:8000`**

### Utilizando Node.js (`serve`):
```bash
npx serve .
```

### Utilizando VS Code:
Abra o arquivo `index.html` e selecione a opção **"Open with Live Server"**.

---

## 🗄️ Configuração do Banco de Dados no Supabase

1. Acesse o console do Supabase no projeto:
   **Endpoint REST:** `https://wsltonlgttjorcseoswri.supabase.co`
2. No menu lateral, acesse **SQL Editor** -> **New Query**.
3. Copie todo o conteúdo do arquivo `Specs/sigepi_schema.sql` e execute no editor.
4. O script criará as tabelas `perfis`, `epis`, `emprestimos`, `movimentacoes`, `alertas` e `configuracoes`, além das políticas de Row Level Security (RLS) e Triggers de auditoria.

---

## 🧪 Guia de Teste das Funcionalidades

1. **Dashboard Operacional (`/dashboard`):**
   - Visualize os cards de KPIs (Estoque Ativo Total, Validade Crítica, Solicitações Pendentes e Devoluções Atrasadas).
   - Verifique o gráfico de fluxo de giro semanal renderizado via Chart.js.
2. **Catálogo & Estoque (`/catalogo-estoque`):**
   - Teste a busca dinâmica e selecione os itens para visualizar a **Ficha Técnica Individual** com lote, normas ABNT e impressão de etiquetas QR.
3. **Solicitação de EPIs (`/solicitacoes`):**
   - Simule uma solicitação informando o motivo e aceitando o termo de guarda e conservação da NR-06.
4. **Liberação & Scanner no Balcão (`/liberacoes-scanner`):**
   - Pressione **F2** para focar no campo de validação rápida.
   - Digite um código de retirada (exemplo: `RET-8942`) e clique em **Confirmar e Baixar Estoque** para dar baixa no saldo do almoxarifado.
