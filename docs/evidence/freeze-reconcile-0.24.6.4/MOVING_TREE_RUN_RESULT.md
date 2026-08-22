LOG=/tmp/run_all_contract_closure.log
LINES=    3187
START=2026-08-22T15:27:15
MTIME=2026-08-22T16:21:53
OK=400
FAIL=9
==> tests/final_certification/addon_compatibility.sh
OK tests/final_certification/addon_compatibility.sh
==> tests/final_certification/e2e_matrix.sh
OK tests/final_certification/e2e_matrix.sh
==> tests/final_certification/saas_matrix.sh
OK tests/final_certification/saas_matrix.sh
==> tests/final_certification/release_checklist.sh
OK tests/final_certification/release_checklist.sh
==> tests/final_certification/finalizer.sh
OK tests/final_certification/finalizer.sh
==> tests/final_certification/evidence.sh
OK tests/final_certification/evidence.sh
phase25_final_certification=PARTIAL — Phase 25 incomplete exit=1 duration=65s ok=0 fail=0
FAIL tests/phase25_final_certification.sh
run_all: FAILED
      "exit_code": 0,
==> tests/security/test_phase24_phase25_readiness.sh
OK test_phase24_phase25_readiness
OK tests/security/test_phase24_phase25_readiness.sh
time="2026-08-22T16:08:06+03:00" level=warning msg="[hostagent] failed to set up forwarding tcp port 5432 (negligible if already forwarded)" error="failed to run [ssh -F /dev/null -o IdentityFile=\"/Volumes/PortableSSD/Apps/Colima/Home/.colima/_lima/_config/user\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o NoHostAuthenticationForLocalhost=yes -o PreferredAuthentications=publickey -o Compression=no -o BatchMode=yes -o IdentitiesOnly=yes -o GSSAPIAuthentication=no -o Ciphers=\"^aes128-gcm@openssh.com,aes256-gcm@openssh.com\" -o User=raafatagha -o ControlMaster=auto -o ControlPath=\"/Volumes/PortableSSD/Apps/Colima/Home/.colima/_lima/colima/ssh.sock\" -o ControlPersist=yes -T -O forward -L 127.0.0.1:5432:127.0.0.1:5432 -N -f -p 51332 127.0.0.1 --]: ``: exit status 255"
apply #2 exit=25
==> tests/phase25_final_certification.sh (light)
phase25_final_certification=PARTIAL — Phase 25 incomplete exit=1 duration=65s ok=0 fail=0
FAIL tests/phase25_final_certification.sh
run_all: FAILED
