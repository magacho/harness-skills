# Relatório de auditoria — <repositório>

Data: <data> · Stack: <stack> · Layout: <layout> · Adaptador: <adaptador>

## Sumário

<Duas ou três frases: em que estado o harness está e qual é a maior alavanca.>

**Maior risco:** <um item>
**Maior ganho barato:** <um item>

## Remover

| item | por quê | regra |
|---|---|---|

## Corrigir

| item | estado atual | estado desejado | regra |
|---|---|---|---|

## Adicionar

| item | por quê | fase |
|---|---|---|

## Instruções falsas encontradas

<Saída de check-claims.sh. Se houver alguma, este é o primeiro item a corrigir:
o agente confia nelas e erra com confiança.>

## Fronteiras

<Estado do grafo, ciclos, dimensão do baseline. Se não houver adaptador para a
stack, declarar aqui explicitamente.>

## Trilha

<Saída de telemetry-status.sh, interpretada. O `estado` é o que importa, e os
quatro significam coisas diferentes:

- `medindo` — há trilha. Relate bloqueios por motivo, reprovações por gate e há
  quantos dias ela cobre. Número sem o tamanho da trilha ao lado não diz nada.
- `sem-emissor` — o harness é de uma versão anterior à telemetria. **Não escreva
  "0 bloqueios"**: ninguém estava medindo, e isso é lacuna da instalação, não
  fato sobre o repositório. Vai para *Adicionar*.
- `desligada` — decisão registrada do projeto. Registre e siga; não recomende
  religar sem perguntar.
- `vazia` — ligada e ainda sem evento. Diga isso, não "nada foi bloqueado".

Se `allow_efetivo` vier `false`, o modo predominante é `bypassPermissions` e o
`permissions.allow` daquele repositório não tem efeito algum — só as negações
são honradas. Isso é achado de risco, não rodapé: vai para *Corrigir*.>

## Parâmetros pendentes

- [ ] Teto de autonomia (default: supervisionado)
- [ ] Dono do harness — **obrigatório**
- [ ] Ritmo da catraca

## Conformidade

<Checklist preenchido.>

## Recomendação

<Instalar / instalar parcialmente / não instalar, com uma frase de justificativa.>
