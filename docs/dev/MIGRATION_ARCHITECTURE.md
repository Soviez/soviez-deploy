# Migration Architecture

Phased under `src/migration/` (P17 discovery → P22 archive). Cutover banners `NO SOURCE PURGE`. Assert helpers deny purge flags. S4 quarantine integrates before unsafe cutover promotion.

No `--merge-in` command.
