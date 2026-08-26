# Merge de .claude/settings.json — o do harness sobre o do projeto.
#
#   jq -n -f merge-settings.jq --slurpfile v <projeto.json> --slurpfile n <harness.json>
#
# Existe como arquivo próprio, e não como três linhas no meio do gerador, porque
# tem regra por caminho e precisa de teste. O `*` do jq parece resolver isto e
# não resolve: em array, o lado direito SUBSTITUI. Foi assim que um reinstall
# apagou 11 negações de produção que o projeto tinha escrito à mão, reportando
# sucesso.
#
# Quatro regras, cada uma por um modo de perda real:
#
#   objeto        merge recursivo, chave por chave
#   permissions   união de conjunto — o que o projeto negou continua negado (A7)
#   hooks         entrada do harness é substituída; entrada do projeto fica
#   escalar       o novo vence

def uniao($a; $b): (($a // []) + ($b // [])) | unique;

# Entrada de hook que o harness é dono: aponta para um dos quatro arquivos que
# ele escreve. O critério é o caminho, e não o objeto inteiro, para valer entre
# versões — comparar o objeto deixaria a entrada velha para trás na primeira vez
# que um timeout mudasse, e o repositório rodaria o hook duas vezes.
def do_harness:
  [ .hooks[]?.command? // empty ]
  | any(test("/\\.claude/hooks/(on-edit|verify|guard-prod|cleanup)\\.sh"));

# Merge recursivo genérico. Array cai no caso escalar de propósito: os dois
# arrays que precisam de união estão nomeados abaixo, e somar array desconhecido
# às cegas produziria duplicata em lista ordenada.
def fundir($novo):
  . as $velho
  | if ($velho | type) == "object" and ($novo | type) == "object"
    then reduce ((($velho | keys_unsorted) + ($novo | keys_unsorted)) | unique)[] as $k
           ({};
            .[$k] = (if ($novo | has($k)) | not then $velho[$k]
                     elif ($velho | has($k)) | not then $novo[$k]
                     else ($velho[$k] | fundir($novo[$k])) end))
    else $novo
    end;

($v[0] // {}) as $velho
| ($n[0] // {}) as $novo
| ($velho | fundir($novo))

# permissions: conjunto, sempre crescente. A7 → R5 permite restringir abaixo do
# teto, nunca afrouxar — então nada que já estava negado sai daqui.
| .permissions.allow = uniao($velho.permissions.allow; $novo.permissions.allow)
| .permissions.deny  = uniao($velho.permissions.deny;  $novo.permissions.deny)

# hooks: o harness é dono das entradas dele e de mais nenhuma. As do projeto
# atravessam intactas; as antigas do harness saem para dar lugar às novas.
| .hooks = (
    [ ((($velho.hooks // {}) | keys_unsorted) + (($novo.hooks // {}) | keys_unsorted)) | unique ][0]
    | map(. as $ev
          | { ($ev): ( [ (($velho.hooks[$ev] // [])[] | select(do_harness | not)) ]
                       + (($novo.hooks[$ev] // [])) ) })
    | add // {}
    | with_entries(select(.value | length > 0))
  )
| if (.hooks | length) == 0 then del(.hooks) else . end

# Não inventar chave que nenhum dos dois lados tinha: `settings.json` sem
# permissions continua sem permissions, em vez de ganhar dois arrays vazios.
| .permissions |= (with_entries(select(.value | length > 0)))
| if (.permissions | length) == 0 then del(.permissions) else . end
