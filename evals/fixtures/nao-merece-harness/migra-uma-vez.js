// Script de migração de uso único. Roda uma vez, some depois.
const linhas = process.argv.slice(2);
console.log(linhas.map((l) => l.trim().toUpperCase()).join("\n"));
