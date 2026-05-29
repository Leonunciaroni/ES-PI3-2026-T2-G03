# 📱 MesclaInvest — Plataforma Mobile de Investimento Simulado (PI3)

Protótipo funcional (Flutter + Firebase) para **simular** um ecossistema de investimento em startups do hub de inovação **Mescla** (PUC-Campinas). A experiência combina “rede social corporativa” com “corretora”: você acompanha startups, consome materiais públicos, interage com empreendedores e negocia **tokens simulados** em um balcão interno.

- **Repositório**: `ES-PI3-2026-T2-G03`
- **Contexto acadêmico**: Projeto Integrador 3 — Engenharia de Software — PUC-Campinas (2026)
- **Documento de visão (referência)**: `PI3-2026-Mobile-MesclaInvest.pdf`

## 👥 Equipe

Grupo 03 — Projeto Integrador III (2026)

```bash
- Leonardo Miranda Nunciaroni — 25002726
- Mariana Silva Ferrarez — 25002010
- Matheus Azevedo Teixeira — 25014927
- Miguel Fernandes Costacurta — 25003110
- Pedro Henrique Contardi Soler — 25005592
``` 

## 🎯 Escopo (o que este repositório entrega)

Baseado no Documento de Visão (`PI3-2026-Mobile-MesclaInvest.pdf`), o protótipo contempla:

- **Autenticação (obrigatória)**: cadastro com **nome completo, e-mail, CPF, celular e senha**, login e **“Esqueci minha senha”**.
- **Catálogo de startups**: listagem, filtros por estágio (**Nova**, **Em operação**, **Em expansão**) e tela detalhada.
- **Conteúdo público**: sumário executivo, estrutura societária e materiais multimídia (ex.: vídeos) quando disponíveis.
- **Perguntas aos empreendedores**: criação e visualização de perguntas e respostas (públicas e/ou privadas conforme regras do app).
- **Balcão de tokens (simulado)**: compra/venda de tokens com ofertas/ordens entre usuários cadastrados.
- **Carteira (saldo fictício)**: saldo interno em reais (simulado) para operar.
- **Dashboard (valorização)**: gráficos por período (ex.: diário, semanal, mensal, 6m, YTD) calculados a partir das transações simuladas.
- **Segurança adicional (opcional)**: **MFA/2FA** e atalhos de autenticação local (biometria) conforme suporte do dispositivo.

## 🚫 Não-escopo (regras do PI3)

Este projeto **não** implementa:

- Integração com meios de pagamento reais (cartões, adquirentes, etc.).
- Emissão/negociação real de tokens em blockchain (ERC-20/ERC-721) ou smart contracts (Solidity etc.).
- Oferta pública de valores mobiliários ou qualquer operação financeira real.
- Versão web completa e/ou implantação institucional em produção.

## 🚀 Tecnologias Utilizadas

### Mobile (Frontend)
- **Flutter** + **Dart** (`pubspec.yaml`)
- **Tema Light/Dark** e preferências locais

### Backend / API
- **Node.js 20** + TypeScript/JavaScript
- **Firebase Functions** (`functions/`) em TypeScript

### Autenticação e Banco de Dados
- **Firebase Authentication** (Autenticação do usuário)
- **Firebase Firestore** (NoSQL)
- **Firebase Storage** (Bucket para arquivos)
- **Firebase App Check** (token de debug em desenvolvimento / Play Integrity em release)

### Dev Tools
- **Firebase Emulators** (Auth, Firestore, Functions)
- **Git + GitHub** (Versionamento de código)

## 📋 Pré-requisitos

- **Flutter SDK** instalado (Dart \(>= 3.11\))
- **Node.js 20**
- **Firebase CLI**
- **Android Studio/VS Code** (ou IDE de sua preferência)

## 🔧 Instalação e Execução (ambiente de testes)

### 1) Clone o projeto

```bash
git clone https://github.com/Leonunciaroni/ES-PI3-2026-T2-G03
cd ES-PI3-2026-T2-G03
```

### 2) App Flutter: dependências

```bash
flutter pub get
```

### 3) Backend (Firebase Functions): dependências e build

```bash
cd functions
npm install
npm run build
cd ..
```

### 4) (Opcional) Configurar e-mail (OTP) para 2FA / recuperação de senha no emulador

As Functions carregam `functions/.env` **apenas no emulador** (ver `functions/src/loadEnv.ts`).

Copie o exemplo:

```bash
copy functions\.env.example functions\.env
```

Variáveis esperadas:

```env
SMTP_USER=seu_email@gmail.com
SMTP_PASS=senha_de_aplicacao_sem_espacos
SMTP_FROM=seu_email@gmail.com
```

> Sem SMTP no emulador, o fluxo não falha: o OTP é registrado nos logs das Functions (útil para desenvolvimento local).

### 5) Subir Firebase Emulators (Auth + Firestore + Functions)

```bash
firebase emulators:start
```

Portas configuradas em `firebase.json`:

- Auth: `9099`
- Firestore: `8080`
- Functions: `5001`
- Emulator UI: `4000`

### 6) Rodar o app (Flutter) apontando para Functions do emulador

```bash
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true
```

Host/porta usados automaticamente:

- **Android Emulator**: `10.0.2.2:5001`
- **iOS**: `127.0.0.1:5001`
- **Web**: `localhost:5001`

Android **físico** na mesma rede do PC:

```bash
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true --dart-define=FUNCTIONS_EMULATOR_HOST=192.168.0.10
```

> Dica: o setup de emulador de Functions no app está em `lib/firebase_dev_setup.dart`.

## 📁 Estrutura do Projeto

```text
ES-PI3-2026-T2-G03/
├── lib/                          # App Flutter (UI, navegação, serviços)
│   ├── auth/                     # Login, cadastro, reset, 2FA/MFA
│   ├── catalog/                  # Catálogo de startups + detalhes
│   ├── balcao/                   # Balcão (ordens, compra/venda, telas)
│   ├── carteira/                 # Carteira (saldo fictício, movimentações)
│   ├── dashboard/                # Gráficos de performance/valorização
│   ├── onboarding/               # Tela de primeiros passos e explicação da plataforma
│   ├── perfil/                   # Perfil + preferências (segurança, aparência)
│   ├── theme/                    # Tema, cores, modo escuro, scroll behavior
│   ├── firebase_dev_setup.dart   # Emulador de Functions (host/porta)
│   ├── firebase_options.dart     # Config Firebase (gerado)
│   └── main.dart                 # Bootstrap do app + App Check
│
├── functions/                    # Backend (Firebase Functions)
│   ├── src/
│   │   ├── auth/                 # 2FA + recuperação por OTP (SMTP)
│   │   ├── startups/             # Listagem/detalhe + perguntas
│   │   ├── balcao/               # Ordens, cancelamento, match engine
│   │   └── wallet/               # Carteira + performance + simulação
│   ├── .env.example              # Exemplo para SMTP no emulador
│   └── package.json
│
├── firebase.json                 # Emulators + config Firebase
├── firestore.rules               # Regras Firestore
├── storage.rules                 # Regras Storage
├── PI3-2026-Mobile-MesclaInvest.pdf
└── README.md
```

## ✅ Funcionalidades (visão por módulos)

### 🔐 Autenticação e Segurança
- Cadastro e login
- Recuperação de senha
- **MFA/2FA**

### 🏢 Catálogo de Startups
- Listagem e filtros por estágio
- Tela de detalhes com conteúdo institucional e materiais públicos
- Tela de detalhes dos sócios e membros chave

### 💬 Perguntas e Respostas
- Envio de perguntas aos empreendedores
- Visualização de perguntas/respostas (públicas e/ou privadas conforme regra do app)

### 💱 Balcão (Compra e Venda de Tokens — simulado)
- Ofertas/ordens de compra e venda
- Regras de negociação implementadas no backend (simulação)

### 💰 Carteira (saldo fictício)
- Carregar saldo interno (simulado)
- Visão de movimentações e posições

### 📈 Dashboard (valorização)
- Gráficos por períodos (diário/semanal/mensal/6m/YTD)
- Cálculo baseado em histórico de transações simuladas

## 🎨 Design Features

- **Interface moderna** inspirada em plataformas de investimento + feed informativo
- **Tema claro/escuro**
- Componentização e consistência visual (cores/tipografia/spacing)

## 🧪 Testes

### Backend (Functions)

```bash
cd functions
npm test
```

## 🛟 Troubleshooting

### MFA por SMS no Android e reCAPTCHA no emulador

No Android Emulator, o Firebase pode abrir o navegador com reCAPTCHA (anti-fraude). Para desenvolvimento, use números de teste:

- Firebase Console → Authentication → Sign-in method → Phone → **Phone numbers for testing**

### App Check (debug)

Em debug, o app imprime um token no log. Registre em:

- Firebase Console → App Check → Apps → tokens de debug

## 🔗 Materiais de apoio

- **Mapa mental (Miro)**: [Abrir board](https://miro.com/app/board/uXjVGxJPQ9s=/?share_link_id=395927260522)
- **Design (Figma)**: [Abrir no Figma](https://www.figma.com/design/87md8sUiyxiDjXTXjzfBCK/Untitled?node-id=0-1&t=XTSFoILIAGyVh2PE-1)

## 📄 Observação sobre o Documento de Visão

O arquivo `PI3-2026-Mobile-MesclaInvest.pdf` declara **uso restrito ao contexto acadêmico** da disciplina. Este repositório utiliza o documento como referência de requisitos para implementação do protótipo do PI3.
