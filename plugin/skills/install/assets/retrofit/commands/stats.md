---
description: Lê a trilha do harness e diz o que ela revela
---
Rode `./.harness/stats.sh` (aceita `--since 7d|30d|all|YYYY-MM-DD`).

O script já imprime os números. **Não os repita.** Seu trabalho é a leitura que
ele não faz — e ela é sobre o que está faltando, não sobre o que apareceu:

1. **Gate que nunca disparou.** Um gate com zero reprovações numa trilha longa
   ou está protegendo algo que ninguém tenta violar, ou está desligado por
   engano. Diga qual dos dois, olhando `cobertura` e o estado da catraca.
2. **Catraca parada.** Baseline que não encolhe há muito tempo é dívida
   congelada: o gate parou a decadência e ninguém voltou para pagar. Diga
   quantas entradas são e sugira por onde começar.
3. **Lacuna de cobertura.** `lint (ausente)` ou `formatter (desligado)` não é
   rodapé — é verificação que este repositório não tem. Diga o que custaria
   ligar, e se hoje passaria.
4. **Anti-loop liberando com frequência.** É o sinal de que algum gate reprova
   trabalho legítimo, que é o modo de fracasso nº 1: o time desliga em duas
   semanas.
5. **Modo de permissão.** Se predominar `bypassPermissions`, o `permissions.allow`
   do `settings.json` é decoração e a trava de produção depende só do hook.

Distinga **"nunca disparou"** de **"não há dado"**: zero numa trilha de dois dias
não afirma nada. Se o relatório vier rotulado como reconstruído dos transcripts,
trate os números como aproximação de histórico, não como medição.

Saída: no máximo cinco linhas, cada uma com um achado e o que fazer com ele. Se
não houver achado, diga isso em uma linha. Não edite nada.
