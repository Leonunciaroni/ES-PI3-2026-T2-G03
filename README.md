# ES-PI3-2026-T2-G03

Repositório dedicado ao Projeto Integrador III do grupo 3 do curso de Engenharia de Software da PUC-Campinas.

## Descrição do Projeto

O **MesclaInvest** é parte de um ecossistema digital de investimentos focado no fomento ao empreendedorismo universitário, vinculado ao hub de inovação Mescla da PUC-Campinas. O projeto consiste em um aplicativo móvel que simula um ambiente de negociação de tokens representativos de startups em estágio inicial.

A plataforma permite aos usuários visualizar startups, consultar documentos institucionais, interagir com empreendedores e, no núcleo do sistema, simular a compra e venda de participações digitais em um balcão de negociação interno. O objetivo é criar um ambiente informativo e interativo, promovendo a transparência e o acompanhamento do desenvolvimento de projetos inovadores dentro do contexto acadêmico.

## Integrantes do Grupo

- Leonardo Miranda Nunciaroni - 25002726
- Mariana Silva Ferrarez - 25002010
- Matheus Azevedo Teixeira - 25014927
- Miguel Fernandes Costacurta - 25003110
- Pedro Henrique Contardi Soler - 25005592

## Tecnologias Utilizadas

Este projeto atende aos requisitos arquiteturais obrigatórios da disciplina:

- **Frontend (Mobile):** Flutter (Linguagem Dart)
- **Backend / API:** Node.js (Linguagem TypeScript/JavaScript)
- **Autenticação e Banco de Dados:** Firebase Authentication + Firebase Firestore (NoSQL)
- **Controle de Versão:** Git e GitHub

## Observações de desenvolvimento

- **Testes com autenticação:** evite chamadas reais ao Firebase Auth em testes automatizados; use mocks/fakes para CI estável e sem rede. A implementação centraliza mensagens em `lib/auth/services/auth_service.dart` (`AuthService`); testes unitários puros podem importar isso sem `Firebase.initializeApp` se apenas exercitarem `messageForError` / mapeamento de códigos.

- **Configuração no repositório:** ficheiros como `android/app/google-services.json` e `lib/firebase_options.dart` são a configuração padrão de app cliente. Não substituem segredos de backend; a política de segurança no console (regras do Firestore, chaves, **App Check** em produção, etc.) é o que protege dados e API.

- **Emulador local (Firebase Functions + app):** no diretório `functions/`, após `npm install`, rode `npm run build`, depois `cd ..` realizar o comando `firebase emulators:start`. No Flutter, em debug, use `flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true` para o app chamar a callable no host correto (Android Emulator: `10.0.2.2:5001`; iOS/desktop: `localhost:5001`). As callables do projeto usam a região **`us-central1`** (igual a `FirebaseFunctions.instanceFor(region: 'us-central1')`).

## Fase atual do projeto

**Última atualização:** 30/03/2026

- **Wireframe:** desenvolvido com base nos conceitos aprendidos nas aulas de PIEU, com foco em melhorar a usabilidade e a experiência do usuário.
- **Design:** primeira versão criada no Figma, utilizando uma paleta de cores em tons de roxo alinhada com a ideia inicial do projeto.
- **Arquivos:** o wireframe e outros materiais de apoio estão disponíveis na branch **`Arquivos-Geral`**.

### Conteúdo da branch `Arquivos-Geral`

- **MapaMental-MesclaInvest.jpg** — mapa mental do projeto MesclaInvest.
- **five-startups.xlsx** — planilha com cinco startups utilizadas como referência para o aplicativo.
- **wireframeV1.png** — primeira versão do wireframe do aplicativo.

### Links para melhor entendimento do projeto

- **Mapa mental do projeto:**  
  https://miro.com/app/board/uXjVGxJPQ9s=/?share_link_id=395927260522

- **Design no Figma:**  
  https://www.figma.com/design/87md8sUiyxiDjXTXjzfBCK/Untitled?node-id=0-1&t=XTSFoILIAGyVh2PE-1
