# ES-PI3-2026-T2-G03

Repositório dedicado ao Projeto Integrador III do grupo 3 do curso de Engenharia de Software da PUC-Campinas.

## Descrição do Projeto

O **MesclaInvest** é parte de um ecossistema digital de investimentos focado no fomento ao empreendedorismo universitário, vinculado ao hub de inovação Mescla da PUC-Campinas. O projeto consiste em um aplicativo móvel que simula um ambiente de negociação de tokens representativos de startups em estágio inicial.

A plataforma permite aos usuários visualizar startups, consultar documentos institucionais, interagir com empreendedores e, no núcleo do sistema, simular a compra e venda de participações digitais em um balcão de negociação interno. O objetivo é criar um ambiente informativo e interativo, promovendo a transparência e o acompanhamento do desenvolvimento de projetos inovadores dentro do contexto acadêmico.

## Integrantes do Grupo

- Leonardo Miranda Nunciaroni
- Mariana Silva Ferrarez
- Matheus Azevedo Teixeira
- Miguel Fernandes Costacurta
- Pedro Henrique Contardi Soler

## Tecnologias Utilizadas

Este projeto atende aos requisitos arquiteturais obrigatórios da disciplina:

- **Frontend (Mobile):** Flutter (Linguagem Dart)
- **Backend / API:** Node.js (Linguagem TypeScript/JavaScript)
- **Autenticação e Banco de Dados:** Firebase Authentication + Firebase Firestore (NoSQL)
- **Controle de Versão:** Git e GitHub

## Observações de desenvolvimento

- **Testes com autenticação:** evite chamadas reais ao Firebase Auth em testes automatizados; prefira mocks/fakes para manter CI estável e sem dependência de rede. Há testes unitários de `AuthService.messageForError` em `test/auth_service_test.dart` (sem rede, sem `Firebase.initializeApp`).

- **Configuração no repositório:** arquivos como `android/app/google-services.json` e `lib/firebase_options.dart` contêm identificadores do app Firebase (padrão em clientes móveis). Não substituem segredos de backend; o que protege a API e os dados é a **política de segurança no console** (regras do Firestore, restringir chaves, **App Check** em produção, etc.).

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
