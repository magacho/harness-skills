#!/usr/bin/env bash
# Caso: o audit mede a DIMENSÃO do que uma catraca congelaria — quantos god
# files, quantas violações de fronteira. É o número que decide se a catraca é
# obrigatória, e medir errado aqui produz verde sem ter olhado.

echo "→ audit / size-status (dimensão do god file, sem ferramenta)"
t "mede o template e não acha god file"   "$A/size-status.sh $T | jq -e '.acima_do_teto==0'"
t "reporta mediana e p95, não só o total" "$A/size-status.sh $T | jq -e 'has(\"mediana\") and has(\"p95\")'"
t "acha o god file plantado"              "cp -a $F/legado-com-ciclos $W/audit-sz && python3 -c \"open('$W/audit-sz/src/god.js','w').write(chr(10).join(['x']*500)+chr(10))\" && $A/size-status.sh $W/audit-sz | jq -e '.acima_do_teto==1 and .catraca_obrigatoria==true'"
t "o teto é parametrizável"               "$A/size-status.sh $W/audit-sz --ceiling 100000 | jq -e '.acima_do_teto==0'"
t "repo sem código não é 'sem god file'"  "! $A/size-status.sh $F/repo-vazio"
t "e diz que a dimensão não foi medida"   "{ $A/size-status.sh $F/repo-vazio 2>&1 || true; } | grep -q 'não foi medida'"
t "não escreve no repositório auditado" \
  "[ -z \"\$(find $T -newermt '-2 seconds' -type f)\" ]"

echo "→ audit / boundary-status (dimensão do baseline)"
# Regressão: cruzava "src modules" fixo. Repo sem modules/ devolvia ENOENT, não
# media nada e ainda assim saía 0 — a dimensão do baseline, que é o número que
# decide se a catraca é obrigatória, voltava vazia com cara de sucesso.
SA=$W/sem-alvo; mkdir -p "$SA"; echo '{"name":"x"}' > "$SA/package.json"
t "sem diretório de código sai 3, não 0"  "! $A/boundary-status.sh $SA"
t "e diz que não é verde"                 "{ $A/boundary-status.sh $SA 2>&1 || true; } | grep -q 'NÃO é verde'"
t "stack sem adaptador declara a lacuna"  "$A/boundary-status.sh $F/python-sem-adaptador | grep -q ADAPTADOR_INDISPONIVEL"
if [[ $rede -eq 1 ]]; then
  t "mede o grafo com código em src/"     "$A/boundary-status.sh $F/legado-com-ciclos | jq -e '.violacoes == 2'"
  t "reporta os alvos que de fato cruzou" "$A/boundary-status.sh $F/legado-com-ciclos | jq -e '.alvos == [\"src\"]'"
  t "decide se a catraca é obrigatória"   "$A/boundary-status.sh $F/legado-com-ciclos | jq -e '.catraca_obrigatoria == true'"
  bs_antes=$(find $F/legado-com-ciclos -type f | sort | md5sum)
  $A/boundary-status.sh $F/legado-com-ciclos >/dev/null 2>&1
  bs_depois=$(find $F/legado-com-ciclos -type f | sort | md5sum)
  t "sonda o grafo sem escrever no repo"  "[ '$bs_antes' = '$bs_depois' ]"
else
  s "mede o grafo com código em src/"     "dependency-cruiser indisponível (sem rede)"
  s "reporta os alvos que de fato cruzou" "dependency-cruiser indisponível (sem rede)"
  s "decide se a catraca é obrigatória"   "dependency-cruiser indisponível (sem rede)"
  s "sonda o grafo sem escrever no repo"  "dependency-cruiser indisponível (sem rede)"
fi
