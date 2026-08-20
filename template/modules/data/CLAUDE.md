# modules/data — acesso a dados

Único dono do schema. Nenhum outro módulo emite SQL ou conhece nome de tabela.

- Pode importar: `modules/shared`, `modules/domain` (para implementar as portas)
- NUNCA importa: `modules/api`, `modules/web`
- Uma implementação por porta de `domain/ports/`. O tipo de retorno é do domínio,
  não a row do banco — traduza na borda
- Migrations em `migrations/`, append-only. Migration aplicada não se edita
- Se outro módulo precisa de um dado novo, o caminho é uma porta nova, não um
  import de repositório
