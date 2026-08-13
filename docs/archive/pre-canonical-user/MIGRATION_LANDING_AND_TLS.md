# Migration Landing and TLS

1. After DNS is verified, prepare the landing page:  
   `sudo soviez.sh --migration-landing-prepare <pair-id>`
2. Issue TLS for the **migrate** hostname:  
   `sudo soviez.sh --migration-tls-prepare <pair-id>`
3. Confirm routing readiness:  
   `sudo soviez.sh --migration-routing-readiness <pair-id>`

You should see a maintenance page on HTTPS for `migrate.<domain>` only. Your live Production site stays unchanged. Data is still not transferred.
