# modules/web — interface

- Pode importar: `modules/shared`, `modules/api/contracts` (só tipos)
- NUNCA importa: `modules/domain`, `modules/data`, ou qualquer parte de
  `modules/api` fora de `contracts/`
- Nada de regra de negócio aqui. Cálculo de preço, elegibilidade, validação de
  domínio — tudo isso vem do backend. O que fica aqui é apresentação e estado de UI
- Se um componente precisa de um dado que o contrato não expõe, o caminho é mudar
  o contrato, não importar o domínio
