import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'theme/app_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supportsFirebaseCurrentPlatform()) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

bool _supportsFirebaseCurrentPlatform() {
  if (kIsWeb) {
    return true;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // fromSeed ajusta o primary para tons "Material"; fixamos a marca em #6234EA.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedPurple,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.seedPurple,
      onPrimary: const Color(0xFFFFFFFF),
    );

    return MaterialApp(
      title: 'Mescla Invest',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.gradientBottom,
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

























Da prova:
Que excelente vazamento de informações! O professor da outra turma cobrou questões muito focadas em **Lógica de Programação (Dart)** e **Arquitetura de Software (Cloud Functions/Clean Architecture)**.

Como no seu projeto vocês usaram a estrutura de `Repositories` (pelo seu histórico com `startupRepository.ts`), você já tem uma boa base. Vamos resolver e "gabaritar" cada um desses tópicos para você chegar na prova dominando tudo.

---

### 1. Questão de Dart: O Display de 7 Segmentos com Maps
Um display de 7 segmentos forma os números acendendo barrinhas chamadas de `a`, `b`, `c`, `d`, `e`, `f`, `g`. O número "0", por exemplo, acende todas as barras em volta (`a,b,c,d,e,f`) e deixa o meio (`g`) apagado.

Aqui está o código exato que resolve o que foi pedido na prova:

```dart
class DisplaySeteSegmentos {
  // 1º Requisito: Map "final" que não pode ser alterado.
  // Ele mapeia o NÚMERO para uma Lista dos segmentos que formam ele.
  final Map<String, List<String>> digitos = {
    '0': ['a', 'b', 'c', 'd', 'e', 'f'],
    '1': ['b', 'c'],
    '2': ['a', 'b', 'd', 'e', 'g'],
    // ... preencheria o resto até o 9
  };

  // 2º Requisito: Map com os segmentos todos desligados (false).
  Map<String, bool> segmentos = {
    'a': false, 'b': false, 'c': false, 'd': false,
    'e': false, 'f': false, 'g': false,
  };

  // 3º Requisito: Void On (Liga um número)
  void on(String numero) {
    off(); // Apaga tudo antes de desenhar o número novo
    
    // Verifica se o número existe no nosso Map final
    if (digitos.containsKey(numero)) {
      // Pega as letras do número e muda o estado para true (ligado)
      for (String letra in digitos[numero]!) {
        segmentos[letra] = true;
      }
      print("Display ligado no $numero: $segmentos");
    }
  }

  // 4º Requisito: Void Off (Desliga tudo)
  void off() {
    // Transforma todos os valores do map em false
    segmentos.updateAll((chave, valor) => false);
    print("Display apagado.");
  }

  // 5º Requisito: Void Mover (Possivelmente é testar a transição entre números)
  void mover(List<String> sequencia) {
    for (String num in sequencia) {
      on(num); // Vai ligando um após o outro
    }
  }
}

void main() {
  var display = DisplaySeteSegmentos();
  display.on('0'); // Vai ligar o 0
  display.off();   // Vai desligar
}
```

---

### 2. Questão Cloud Functions: POST e Número Primo com JSON
Essa questão pede a criação de uma API HTTP em Firebase Functions. Ela exige que você extraia dados de uma requisição `POST`, aplique uma regra de negócio (cálculo de primo) e retorne um objeto estruturado em JSON.

**Código da Função (TypeScript/Node.js):**
```typescript
import * as functions from 'firebase-functions';

export const verificarPrimo = functions.https.onRequest((req, res) => {
  // 1. Obriga que seja uma requisição POST
  if (req.method !== 'POST') {
    res.status(405).json({ erro: "Método não permitido, use POST." });
    return;
  }

  // 2. Extrai o número do body da requisição (ex: body do Postman: { "numero": 7 })
  const numero = req.body.numero;

  // Validação
  if (typeof numero !== 'number') {
    res.status(400).json({ erro: "Forneça um número válido." });
    return;
  }

  // 3. Lógica matemática para descobrir se é primo
  let isPrimo = true;
  if (numero <= 1) {
    isPrimo = false;
  } else {
    for (let i = 2; i <= Math.sqrt(numero); i++) {
      if (numero % i === 0) {
        isPrimo = false;
        break;
      }
    }
  }

  // 4. Retorna a resposta no formato JSON usando res.json()
  res.status(200).json({
    numeroAvaliado: numero,
    resultado: isPrimo ? "É primo" : "Não é primo",
    booleano: isPrimo
  });
});
```

---

### 3. Teoria de Arquitetura: O que vai dentro dos "Handlers" (Controladores)
Se cair uma múltipla escolha perguntando a responsabilidade de um **Handler** (ou Controller), você precisa lembrar que ele é a **porta de entrada e saída** da API.

**O que vai DENTRO do Handler?**
* **A correta é a alternativa que disser:** *"Receber as requisições HTTP (`req`), extrair e validar os dados de entrada (body, query, params), chamar a camada de serviço/negócio, e formatar e enviar a resposta HTTP (`res`) definindo os Status Codes (200, 400, 500) em formato JSON."*
* **Mata-Mata:** Handler **NÃO** acessa banco de dados diretamente e **NÃO** possui regras de negócio complexas (isso é papel dos Services/Repositories).

---

### 4. Teoria de Arquitetura: O que vai dentro dos "Repositories"
Vocês usaram muito isso no Firebase (`startupRepository.ts`). O Repositório é a camada focada exclusivamente em **dados**.

**O que vai DENTRO do Repository?**
* **A correta é a alternativa que disser:** *"Isolar e centralizar o acesso aos dados. É o único local que deve conter a comunicação direta com o Banco de Dados (como comandos do Firestore: `.collection()`, `.doc()`, `.get()`, `.set()`). Ele converte os dados que vêm do banco em objetos para o sistema usar."*
* **Mata-Mata:** Repository **NÃO** sabe o que é requisição HTTP (`req`/`res`) e **NÃO** toma decisões de regras de negócio. Ele obedece ordens: "Busque essa Startup", "Grave essa Startup". 

Dê uma boa lida nesses pontos porque eles conectam exatamente o que você já fez no código do seu projeto com as perguntas da prova! Se tiver alguma dúvida sobre a lógica de primo ou sobre os Maps do Dart, é só mandar.