# Custom Addon Failure

## Fixture
Incompatible disposable addon `p15_bad_addon` raises `RuntimeError` during candidate upgrade (`SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL=1` / real addon mount path).

## Expected
- Code: `UPDATE_CANDIDATE_UPGRADE_FAILED`
- Production `current_digest` **unchanged**
- No switch; candidate failure is terminal for that attempt (retryable path per engine)

## Result
PASS — Production protected; failure code emitted.
