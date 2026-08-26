import { cobrar } from "./cobrar";
export function faturar(v: number): number { return v > 0 ? cobrar(v - 1) : 0; }
