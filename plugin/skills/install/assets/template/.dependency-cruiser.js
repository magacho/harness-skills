/**
 * Fronteiras de módulo. Esta é a arquitetura — o CLAUDE.md só a explica.
 * Mudar uma regra aqui exige ADR em docs/adr/.
 */
module.exports = {
  forbidden: [
    {
      name: "sem-ciclos",
      severity: "error",
      comment: "Ciclo é a maior causa de código emaranhado.",
      from: {},
      to: { circular: true },
    },
    {
      name: "domain-e-puro",
      severity: "error",
      comment:
        "domain só conhece shared e a si mesmo. I/O sai por domain/ports.",
      from: { path: "^modules/domain" },
      to: {
        pathNot: "^(modules/domain|modules/shared)",
        dependencyTypesNot: ["type-only"],
      },
    },
    {
      name: "domain-nao-conhece-transporte",
      severity: "error",
      comment:
        "Nenhum cliente de infra em regra de negócio. Adaptador vive em data/ ou api/.",
      from: { path: "^modules/domain" },
      to: {
        dependencyTypes: ["npm"],
        path: "(prisma|pg|kafkajs|@aws-sdk|express|fastify|react|redis|ioredis|amqplib)",
      },
    },
    {
      name: "data-nao-sobe",
      severity: "error",
      comment: "data implementa portas do domain. Não conhece api nem web.",
      from: { path: "^modules/data" },
      to: { path: "^modules/(api|web)" },
    },
    {
      name: "web-so-ve-contratos",
      severity: "error",
      comment:
        "web fala com o backend por api/contracts. Nunca importa domain, data, ou o resto de api.",
      from: { path: "^modules/web" },
      to: {
        path: "^modules/(domain|data|api)",
        pathNot: "^modules/api/contracts",
      },
    },
    {
      name: "api-nao-importa-web",
      severity: "error",
      from: { path: "^modules/api" },
      to: { path: "^modules/web" },
    },
    {
      name: "shared-nao-depende-de-ninguem",
      severity: "error",
      comment: "shared é folha. Se precisa importar módulo, não é shared.",
      from: { path: "^modules/shared" },
      to: { path: "^modules/(domain|data|api|web)" },
    },
    {
      name: "sem-orfaos",
      severity: "warn",
      from: { orphan: true, pathNot: "\\.d\\.ts$" },
      to: {},
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    // Sem isto o dependency-cruiser 18 não resolve import TypeScript sem
    // extensão ("./invoice"): registra o especificador cru e a regra de
    // direção não casa. A 16, que este package.json fixa, resolvia sozinha —
    // por isso a lacuna passou. O gate tem de dar a mesma resposta nas duas.
    enhancedResolveOptions: {
      extensions: [".ts", ".tsx", ".d.ts", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs", ".json"],
    },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: "tsconfig.json" },
    // A catraca é do harness, não da ferramenta (V8): a comparação com o
    // baseline vive em .harness/gate-boundaries.sh, no formato
    // [{origem, destino, regra}], para valer em qualquer linguagem. Por isso
    // knownViolations fica desligado aqui de propósito.
  },
};
