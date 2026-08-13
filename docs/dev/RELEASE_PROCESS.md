# Release process (Planned)

1. Owner authorizes phase/release.
2. Bundle `src` → `dist/soviez.sh` with checksum + signature.
3. Never hand-edit dist.
4. Publish signed artifacts; private image by digest.
5. Update PROJECT_STATE and CHANGELOG.
6. Commit/push only with explicit owner request.
