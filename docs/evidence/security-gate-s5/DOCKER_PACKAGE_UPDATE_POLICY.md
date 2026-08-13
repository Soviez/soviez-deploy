# DOCKER_PACKAGE_UPDATE_POLICY

Docker Engine/containerd host package upgrades are high-risk for publish/network regressions. S5 requires post-change Docker restart matrix + port/network semantic validation before PASS. Focused Docker restart matrix: **PASS**.
