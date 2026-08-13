# TEST_RESULTS

## npm run test:phase5
14 pass / 0 fail

## npm run test:phase5-db
8 pass / 0 fail (Docker isolated Postgres)

## npm run test:commercial-closure
Phase 3+4 unit + commercial-db: all pass

## Commands
```
npm run test:phase5
npm run test:phase5-db
npm run test:commercial-closure
npm run typecheck
npm run lint
npx next build   # without apply-migrations (live migrate unauthorized)
```
