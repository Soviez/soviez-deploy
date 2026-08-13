# Image Cleanup E2E

## Scenario
1. Dry-run with current=`p15-v15`, rollback=`p15-v14`
2. Force window elapsed for test
3. `p15-v13` protected by other Production + Stage + stopped container → inspect still succeeds after execute
4. Remove protecting refs → cleanup may delete unreferenced managed image
5. Forbidden prune static gate remains green

## Result
PASS — exact delete path; protections hold; no broad prune.
