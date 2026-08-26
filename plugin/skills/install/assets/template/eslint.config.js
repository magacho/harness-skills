/**
 * Lint. Aqui moram os limites de FUNÇÃO; o limite de ARQUIVO é a catraca do
 * harness (`.harness/gate-size.sh`).
 *
 * A divisão é de propósito. Tamanho de arquivo tem de valer em qualquer
 * linguagem e em legado — precisa de baseline, e o baseline é do harness, nunca
 * da ferramenta (V8 → R7,R12). Tamanho de função é análise sintática: quem sabe
 * onde uma função começa é o parser, não o `wc`. Duas perguntas, dois donos, uma
 * resposta cada — `max-lines` aqui daria uma segunda resposta para a pergunta
 * que a catraca já responde.
 *
 * Só regras de tamanho e forma. Não ligamos `recommended`: gate que reprova
 * trabalho legítimo no primeiro dia é desligado em duas semanas, e gate
 * desligado é pior que gate nenhum. Acrescente regra quando ela tiver dono.
 */
const tseslint = require("typescript-eslint");

module.exports = [
  { ignores: ["**/node_modules/**", "**/dist/**", "**/build/**", "**/coverage/**"] },

  {
    files: ["**/*.{ts,tsx,mts,cts}"],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: { sourceType: "module", ecmaVersion: 2023 },
    },
    rules: {
      // Uma função de 300 linhas é o que obriga a carregar tudo em contexto
      // para mudar uma coisa — é o oposto de R4. Sessenta linhas é folgado
      // para caso de uso real e aperta o handler que virou script.
      "max-lines-per-function": [
        "error",
        { max: 60, skipBlankLines: true, skipComments: true, IIFEs: true },
      ],
      // Ramificação é o que a IA gera bem e revisa mal: cada caminho novo é um
      // teste que ninguém escreveu.
      complexity: ["error", { max: 10 }],
      // Aninhamento profundo esconde o caminho de erro dentro do caminho felizardo.
      "max-depth": ["error", 4],
    },
  },

  {
    // Teste é bloco descritivo, não unidade de lógica: `describe` com trinta
    // casos é bom teste e passaria dos sessenta. Medir função aqui empurraria
    // o time a escrever menos caso — o gate pagaria em cobertura o que
    // cobrasse em forma.
    files: ["**/*.{test,spec}.{ts,tsx}", "**/__tests__/**"],
    rules: { "max-lines-per-function": "off", complexity: "off" },
  },
];
