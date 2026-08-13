# Rollback-Window Closure Model

## Distinction

| Concept | Default | Role |
|---------|---------|------|
| Immediate rollback window | 30 minutes (Phase 21) | Automatic installer rollback eligibility (R0–R2) |
| Stabilization observation | configurable; recommend 24h | Sustained destination health evidence |
| Archival eligibility | after stabilization PASS + owner confirm | May begin archive plan |

**No automatic closure based only on elapsed time.**

## Closure mode (recommended)

```text
automatic eligibility
+
explicit owner confirmation
```

## Prerequisites (minimum)

1. Phase 21 completed successfully  
2. Destination traffic owner for full configured observation period  
3. Destination health sustained  
4. No unresolved critical incidents  
5. No split-brain  
6. No source business writes  
7. Destination DB growth consistent  
8. Destination filestore growth consistent  
9. Destination integrations stable  
10. No duplicate payments / webhooks  
11. No queue backlog anomaly  
12. Destination verified backup current  
13. Source rollback backup still valid  
14. Source retained and internally reachable  
15. Source certificate valid or archive policy ready  
16. DNS stable; no meaningful traffic to source  
17. Immediate rollback window expired **and** stabilization gates PASS  
18. No active rollback operation  
19. Owner closure confirmation  
20. No Phase 21 recovery state  

## After closure commit

- Automatic rollback **disabled**
- Destination remains traffic owner
- Source no longer immediate rollback origin
- Manual recovery still possible
- **No data deletion**
