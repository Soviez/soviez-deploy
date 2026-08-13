# License guard integration

## Existing entrypoints
`store_license_activation`, `action_activate_soviez_license`, `/web/activate_software`, deactivation wizard, migration receipt.

## Planned auto-activate
Call ORM via maintenance stdin (pattern already used for password set). No direct SQL. Prefer zero Cython API changes.
