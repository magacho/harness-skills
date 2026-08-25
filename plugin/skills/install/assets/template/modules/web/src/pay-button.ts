import type { PayInvoiceRequest, PayInvoiceResponse } from "../../api/contracts/invoice";

/** web só conhece o contrato. Não sabe o que "payable" significa. */
export async function pay(req: PayInvoiceRequest): Promise<PayInvoiceResponse> {
  const res = await fetch("/api/invoices/pay", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(req),
  });
  return res.json();
}
