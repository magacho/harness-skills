import type { InvoiceId } from "../../domain/src/invoice";
import { payInvoice } from "../../domain/src/pay-invoice";
import type { InvoiceRepository } from "../../domain/ports/invoice-repository";
import type { PayInvoiceRequest, PayInvoiceResponse } from "../contracts/invoice";

/** Sem regra de negócio: valida, delega, serializa. */
export const makePayInvoiceHandler = (repo: InvoiceRepository) => {
  const useCase = payInvoice(repo);
  return async (body: PayInvoiceRequest): Promise<PayInvoiceResponse> => {
    const result = await useCase(body.invoiceId as InvoiceId);
    return result.ok
      ? { status: "paid" }
      : { status: "error", code: result.error as never };
  };
};
