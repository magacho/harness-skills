import { type Result, err, ok } from "../../shared/src/result";
import type { InvoiceRepository } from "../ports/invoice-repository";
import { type InvoiceId, isPayable } from "./invoice";

/** Caso de uso puro: recebe a porta, não a constrói. Testável sem banco. */
export const payInvoice =
  (repo: InvoiceRepository) =>
  async (id: InvoiceId): Promise<Result<void, string>> => {
    const invoice = await repo.byId(id);
    if (!invoice) return err("invoice_not_found");
    if (!isPayable(invoice)) return err("invoice_not_payable");
    await repo.save({ ...invoice, status: "paid" });
    return ok(undefined);
  };
