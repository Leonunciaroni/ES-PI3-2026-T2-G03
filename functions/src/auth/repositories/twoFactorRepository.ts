// Principal: Miguel Fernandes Costacurta - 25003110
// RA: 25003110
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ CONCEITOS RÁPIDOS (leia antes das linhas)                                │
// │                                                                          │
// │ SHA-256: algoritmo que transforma texto em um "resumo" fixo e            │
// │ irreversível. Ex.: "123456" → "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a" │
// │ Por quê? Guardamos o hash no Firestore, não o código puro. Se alguém     │
// │ vazar o banco, não descobre o OTP original.                              │
// │                                                                          │
// │ .update(code)  → "alimenta" o algoritmo com o texto do código            │
// │ .digest("hex") → gera o hash final em formato hexadecimal (0-9, a-f)     │
// │                                                                          │
// │ Promise (TypeScript/JS): representa algo que vai terminar no FUTURO      │
// │ (ex.: salvar no Firestore). async/await espera a Promise terminar.       │
// │ Ex.: Promise<void> = "vai acabar, mas não devolve valor útil"            │
// │      Promise<VerifyResult> = "vai acabar e devolve ok/reason"            │
// │                                                                          │
// │ late (Dart/Flutter): variável declarada agora, valor preenchido DEPOIS.  │
// │ Promise (TS): operação assíncrona que termina DEPOIS (no tempo).         │
// │ São coisas DIFERENTES: late = memória Dart; Promise = espera de rede/IO. │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Repositório de código 2FA (Firestore) para autenticação em duas etapas.
// Escopo: salvar OTP e validar OTP. Não envia e-mail (isso fica em twoFactor.ts).

// Importa utilitários do Firestore Admin (servidor Firebase).
// FieldValue → valores especiais (timestamp do servidor, incremento).
// Timestamp → data/hora com expiração do código.
import {FieldValue, Timestamp} from "firebase-admin/firestore";

// Importa o módulo nativo de criptografia do Node.js (roda no servidor).
import crypto from "node:crypto";

// Instância do Firestore já configurada em ../shared/firebase.js.
import {db} from "../shared/firebase.js";

// Tipo TypeScript que descreve o formato do documento salvo no Firestore.
import {TwoFactorCodeDocument} from "../types/index.js";

// Aponta para a coleção onde ficam os códigos OTP temporários.
// Cada documento usa o uid do usuário como ID: two_factor_codes/{uid}.
const collection = db.collection("two_factor_codes");

// Tempo de vida do código: 5 minutos em milissegundos (5 × 60 × 1000).
const CODE_TTL_MS = 5 * 60 * 1000;

// Máximo de tentativas erradas antes de bloquear (pedir código novo).
const MAX_ATTEMPTS = 5;

// Converte o código OTP (ex.: "482910") em hash SHA-256 hexadecimal.
// Fluxo: createHash → update (entrada) → digest (saída final).
function hashCode(code: string): string {
  return crypto.createHash("sha256").update(code).digest("hex");
}

// Salva (ou substitui) um código 2FA para o uid informado.
// async = função assíncrona; Promise<void> = termina sem retornar dado útil.
export async function saveCode(uid: string, code: string): Promise<void> {
  // Calcula quando o código expira: agora + 5 minutos.
  const expiresAt = Timestamp.fromMillis(Date.now() + CODE_TTL_MS);

  // Monta o objeto que será gravado no Firestore.
  const doc: TwoFactorCodeDocument = {
    codeHash: hashCode(code), // hash do OTP, não o número em claro
    expiresAt, // quando deixa de valer
    attempts: 0, // contador de erros começa em zero
    createdAt: FieldValue.serverTimestamp(), // hora do servidor Firebase
  };

  // await espera a Promise do Firestore concluir antes de seguir.
  // .set(doc) cria ou sobrescreve o documento two_factor_codes/{uid}.
  await collection.doc(uid).set(doc);
}

// Tipo de retorno da verificação: sucesso OU falha com motivo específico.
export type VerifyResult =
  | {ok: true}
  | {ok: false; reason: "not_found" | "expired" | "max_attempts" | "invalid"};

// Verifica o código digitado contra o que está salvo no Firestore.
// Incrementa tentativas se errar; apaga o documento se acertar.
export async function verifyCode(
  uid: string,
  code: string
): Promise<VerifyResult> {
  // Referência ao documento deste usuário na coleção.
  const ref = collection.doc(uid);

  // Busca o documento no Firestore (operação assíncrona → await).
  const snap = await ref.get();

  // Se não existe código salvo, o usuário precisa pedir um novo.
  if (!snap.exists) {
    return {ok: false, reason: "not_found"};
  }

  // Lê os campos do documento (codeHash, expiresAt, attempts, etc.).
  const data = snap.data() as TwoFactorCodeDocument;

  // Compara expiração com o horário atual. toMillis() = timestamp em ms.
  if (data.expiresAt.toMillis() < Date.now()) {
    await ref.delete(); // código velho: remove do banco
    return {ok: false, reason: "expired"};
  }

  // Bloqueia se já errou demais (5 tentativas).
  if (data.attempts >= MAX_ATTEMPTS) {
    return {ok: false, reason: "max_attempts"};
  }

  // Compara o código digitado com o salvo.
  // Aceita formato legado (data.code) ou hash atual (data.codeHash).
  const matches =
    (typeof data.code === "string" && data.code === code) ||
    (typeof data.codeHash === "string" && data.codeHash === hashCode(code));

  // Código errado: soma +1 em attempts e informa invalid.
  if (!matches) {
    await ref.update({attempts: FieldValue.increment(1)});
    return {ok: false, reason: "invalid"};
  }

  // Código certo: apaga o documento (OTP de uso único) e retorna sucesso.
  await ref.delete();
  return {ok: true};
}
