# DESTINATION_ROUTING_BOUNDARY.md

## May

- Validate Nginx present  
- Create **isolated** migration-site config (`server_name` = migration FQDN)  
- Serve neutral landing  
- Issue/validate migration-subdomain TLS  
- Health-check landing  
- Prepare **disabled** future ERP route template (optional OD-31)  

## Must not

- Attach customer Production database  
- Start Production ERP / activate License  
- Expose customer ERP login on any name  
- Route Production domain to destination  
- Start streaming migration  
- Consume Migration Token  

## Neutrality

Destination remains non-Production. Landing is the only public app surface in Phase 18.
