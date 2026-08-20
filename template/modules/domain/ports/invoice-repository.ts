import type { Invoice, InvoiceId } from "../src/invoice";

/** Porta. Implementada em modules/data. O domain nunca sabe onde isto grava. */
export interface InvoiceRepository {
  byId(id: InvoiceId): Promise<Invoice | null>;
  save(invoice: Invoice): Promise<void>;
}
