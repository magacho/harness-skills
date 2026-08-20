# Checklist de conformidade

Extraído de HARNESS.md §12. Verificável, não declarável.

- [ ] `CLAUDE.md` na raiz, e **todo comando citado nele executa** `C4 → R1`
- [ ] `CLAUDE.md` por módulo, com o que importa e o que não importa `C3 → R1,R4`
- [ ] Nenhuma garantia depende de configuração pessoal `D1 → R8`
- [ ] Hook por edição: assíncrono, silencioso, não escreve no contexto `V1 → R9`
- [ ] Gate de turno: filtra por arquivos da sessão, bloqueia de verdade `V3,V4 → R2`
- [ ] Guarda anti-loop presente; contador zera ao passar `V5 → R2`
- [ ] **Violação plantada de propósito reprova** `V9 → R3`
- [ ] Baseline de catraca existe se havia violações; e encolhe `V7 → R7`
- [ ] Todo gate roda como comando à mão `D5 → R12`
- [ ] Escrita em produção negada em permissão **e** em hook `A2 → R5`
- [ ] Script de investigação existe e é read-only `A3 → R5`
- [ ] Teto de autonomia declarado; elevá-lo exige revisão `A6,A7 → R5`
- [ ] Dono registrado `D6 → R6`
- [ ] Nenhum arquivo do harness contém segredo `A5 → R5`
- [ ] Cada subagente declara o que não repete `G3 → R9`
