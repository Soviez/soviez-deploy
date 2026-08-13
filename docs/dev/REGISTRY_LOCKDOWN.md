# Registry Lockdown

Preferred lifecycle: temp `DOCKER_CONFIG` → login/auth → exact pull/export → verify → logout → delete temp config.

Helpers: `soviez_security_registry_assert_temp_config_clean`, `soviez_security_registry_assert_no_global_auth_for`.

Fixture pull tokens are denied outside disposable test bypass.
