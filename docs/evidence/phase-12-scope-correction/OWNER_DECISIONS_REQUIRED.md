# OWNER_DECISIONS_REQUIRED.md

These questions must be answered by the owner **before** Phase 12 implementation.  
This documentation task does **not** answer them.

1. Is trusted public CA mandatory for Production, or may owner-approved private CA be used?  
2. Is temporary HTTP allowed during Production provisioning?  
3. Does Production remain incomplete until HTTPS passes?  
4. What renewal lead time should be default?  
5. What retry/backoff policy should apply?  
6. Should renewal be fully automatic, operator-confirmed, or policy-configurable?  
7. Should failure trigger warning only, maintenance mode, or block future operations?  
8. Should Stage and Production use the same certificate lifecycle policy?  
9. Are wildcard certificates permitted?  
10. Should ACME provider selection be configurable?  

**Status:** PENDING OWNER  
**Decision log:** D084
