# WebSocket 8072

When workers>0:
- HTTP: 127.0.0.1:8069
- Evented: 127.0.0.1:8072
- Nginx `/` → 8069; `/websocket` + `/longpolling` → 8072
Never public.
