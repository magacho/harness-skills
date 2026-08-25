import { moeda } from "../comum/moeda.js";
export const boleto = (v) => ({ linha: moeda(v) });
