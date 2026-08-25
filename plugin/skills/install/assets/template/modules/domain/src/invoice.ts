export type InvoiceId = string & { readonly __brand: "InvoiceId" };

export type Invoice = {
  id: InvoiceId;
  amountCents: number;
  status: "open" | "paid" | "void";
};

export const isPayable = (i: Invoice): boolean =>
  i.status === "open" && i.amountCents > 0;
