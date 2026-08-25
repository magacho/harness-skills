import { faturar } from "../faturamento/faturar.js";
import { moeda } from "../comum/moeda.js";
export const cobrar = (id) => moeda(faturar(id));
