import type { Invoice, InvoiceId } from "../../domain/src/invoice";
import type { InvoiceRepository } from "../../domain/ports/invoice-repository";

/** Único lugar do sistema que conhece a tabela `invoices`. */
export const makePgInvoiceRepository = (db: {
  query: (sql: string, p: unknown[]) => Promise<{ rows: any[] }>;
}): InvoiceRepository => ({
  async byId(id: InvoiceId) {
    const { rows } = await db.query(
      "select id, amount_cents, status from invoices where id = $1",
      [id],
    );
    return rows[0] ? toDomain(rows[0]) : null;
  },
  async save(invoice: Invoice) {
    await db.query("update invoices set status = $2 where id = $1", [
      invoice.id,
      invoice.status,
    ]);
  },
});

// Tradução na borda: row do banco nunca escapa para o domínio.
const toDomain = (r: any): Invoice => ({
  id: r.id as InvoiceId,
  amountCents: Number(r.amount_cents),
  status: r.status,
});
