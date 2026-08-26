# Checkpoints da instalação

O modo A para entre cada fase e espera o humano. Não é cerimônia: cada parada
existe porque a fase seguinte tem custo de desfazer maior que a anterior.

Em cada checkpoint, exiba **o que foi feito**, **o que foi pulado e por quê**, e
**a decisão que a próxima fase exige**. Depois espere.

---

## Antes da fase 1

| exibir | de onde |
|---|---|
| Modo detectado e por quê | `plan-install.sh` → `.modo` |
| Veredito "merece harness" e razões | `.merece_harness` |
| Módulos detectados, com os nomes reais | `.modulos` |
| Manifesto completo: caminho, fase, status | `.manifesto` |
| Gates que passam hoje e os que não passam | `.gates_hoje` |
| Pendências | `.pendencias` |

**Decisão pedida:** dono (obrigatório, sem default) e teto de autonomia
(default `supervisionado`).

Se `merece_harness.veredito` for `false`: diga por quê e **pare aqui**.

---

## Entre a fase 1 e a fase 2

| exibir | de onde |
|---|---|
| Arquivos escritos | `gen-config.sh` → `.escritos` |
| Arquivos pulados e o motivo de cada um | `.pulados` |
| Quais gates ficaram ligados e quais ficaram de fora | `.harness/harness.json` → `.gates` |
| Quantos arquivos já passam do teto de tamanho | `plan-install.sh` → `.size.acima_do_teto` |
| Se `.claude/settings.json` foi pulado: **as permissões não entraram** | `.pulados`, e `.harness/settings.proposto.json` |
| Teto e dono registrados | `.harness/harness.json` |

**Decisão pedida:** seguir para a catraca.

> A fase 2 é onde o valor chega. Se a instalação parar antes dela, o repositório
> ganhou hooks e não ganhou garantia. Diga isso explicitamente aqui.

---

## Entre a fase 2 e a fase 3

| exibir | de onde |
|---|---|
| Quantas violações de fronteira foram congeladas, por regra | `gen-baseline.sh` → `.fronteira.por_regra` |
| Estado da catraca de fronteira | `.fronteira.catraca` |
| Quantos arquivos de tamanho foram congelados, e o maior | `.tamanho.arquivos_congelados`, `.tamanho.maior` |
| Estado da catraca de tamanho | `.tamanho.catraca` |
| Se não houve adaptador: a lacuna, em uma frase | saída de erro, código 3 |

**Decisão pedida:** seguir para o contexto.

Um baseline grande não é motivo para adiar: é o argumento a favor da catraca. Um
baseline vazio também não é motivo para pular: em repositório limpo, qualquer
violação passa a ser nova a partir de agora.

Se o código 3 apareceu, diga a frase inteira: faltou a catraca de **fronteira**,
e a de **tamanho** está ligada. "Sem catraca" seria falso, e é o tipo de resumo
que faz alguém achar que a fase 2 não entregou nada.

---

## Entre a fase 3 e o encerramento

| exibir | de onde |
|---|---|
| `CLAUDE.md` gerados e pulados | `.escritos` / `.pulados` |
| Se a raiz foi pulada: a proposta, para merge | `.harness/CLAUDE.md.proposto` |
| As linhas "o que este módulo faz" que faltam preencher | os arquivos gerados |

**Decisão pedida:** ratificar o texto antes do teste de fumaça.

---

## Encerramento

Sempre, e nesta ordem:

1. Resultado do `smoke-test.sh`. Se falhou, **a instalação não está concluída**.
2. A lista de pendências que sobrou.
3. O que esta skill **não** instalou: a fase 4 do `PLAN.md` — roster onda 1,
   revisor de mudança e arquiteto.
4. O único critério de sucesso que não dá para fraudar: **o harness continua
   ligado daqui a três meses**. Quem observa isso é o dono registrado.
