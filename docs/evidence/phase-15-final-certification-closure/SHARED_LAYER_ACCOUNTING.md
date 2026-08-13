# Shared Layer Accounting

Cleanup reporting includes `shared_layer_note`: actual free space may be **less** than the sum of logical image sizes because Docker layers are shared.

Installer never claims byte-exact reclamation from image delete alone.
