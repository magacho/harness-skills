import { makePgInvoiceRepository } from "../../data/src/invoice-repository.pg";
import { makePayInvoiceHandler } from "./pay-invoice.handler";

/** Composition root: o único lugar onde as dependências são conectadas. */
export const buildApp = (db: any) => {
  const repo = makePgInvoiceRepository(db);
  return { payInvoice: makePayInvoiceHandler(repo) };
};
