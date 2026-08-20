# Contribuindo

## Antes de abrir PR

    ./scripts/validate.sh
    ./evals/run.sh

Os dois precisam passar. O `validate.sh` aplica ao próprio produto a regra C4 que
o harness cobra dos outros: comando documentado que não executa é instrução falsa.

## Regras deste repositório

**Toda regra nova em `docs/HARNESS.md` rastreia a um resultado de `docs/INTENT.md`.**
Regra sem `→ R` correspondente é cerimônia e será recusada. Se a regra é boa e não
tem R, provavelmente falta um resultado no `INTENT` — proponha os dois juntos.

**Mudança de comportamento da skill exige eval.** Skill que modifica repositório
alheio sem eval é risco não medido. Fixture novo em `evals/fixtures/`.

**Nada de específico de uma empresa.** Este harness é distribuível: exemplos,
nomes de módulo e dados de qualquer organização ficam fora.

## Ordem dos documentos

`INTENT` → `HARNESS` → `PLAN`. Mudança no porquê pode invalidar regras; mudança em
regra pode invalidar o plano. Nunca edite na ordem inversa sem revisar acima.

## Adaptador de linguagem novo

Leia `docs/adapters/README.md`. Os quatro verbos são o contrato. Espere que ele
mude: a primeira revisão a partir da segunda implementação é prevista, não falha.
