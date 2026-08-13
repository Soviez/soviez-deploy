const SECRET_PATTERNS = [
  /Bearer\s+[A-Za-z0-9._-]+/gi,
  /SOVIEZ_UPSTREAM_REGISTRY_TOKEN[=:]\s*\S+/gi,
  /SOVIEZ_UPSTREAM_REGISTRY_USER[=:]\s*\S+/gi,
  /password[=:]\s*\S+/gi,
  /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
];

export function redactSecrets(input: string): string {
  let out = input;
  for (const pattern of SECRET_PATTERNS) {
    out = out.replace(pattern, (match) => {
      if (/^Bearer\s/i.test(match)) return "Bearer [REDACTED]";
      const key = match.split(/[=:]/)[0];
      return `${key}=[REDACTED]`;
    });
  }
  return out;
}

export function safeLog(...args: unknown[]): void {
  const redacted = args.map((arg) => {
    if (typeof arg === "string") return redactSecrets(arg);
    if (arg instanceof Error) {
      return new Error(redactSecrets(arg.message));
    }
    try {
      return redactSecrets(JSON.stringify(arg));
    } catch {
      return "[unserializable]";
    }
  });
  console.log(...redacted);
}

export function safeError(...args: unknown[]): void {
  const redacted = args.map((arg) => {
    if (typeof arg === "string") return redactSecrets(arg);
    if (arg instanceof Error) {
      return new Error(redactSecrets(arg.message));
    }
    try {
      return redactSecrets(JSON.stringify(arg));
    } catch {
      return "[unserializable]";
    }
  });
  console.error(...redacted);
}
