/** API pública para modules/web. Mudança quebrando contrato exige ADR. */
export type PayInvoiceRequest = { invoiceId: string };
export type PayInvoiceResponse =
  | { status: "paid" }
  | { status: "error"; code: "invoice_not_found" | "invoice_not_payable" };
