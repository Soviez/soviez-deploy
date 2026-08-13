# State and recovery (Planned)

Every long operation records phase, inputs hash, checkpoints, and last error.
Resume never restarts from zero if checkpoints exist.
Abort before cutover restores/leaves source operating.
