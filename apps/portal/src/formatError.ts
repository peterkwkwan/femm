/**
 * Turn Supabase Auth / PostgREST / Storage failures into a readable string.
 * Those APIs often return plain `{ message, code, details, hint }` objects
 * (not `Error` instances), so `String(err)` becomes `[object Object]`.
 */
export function formatError(err: unknown): string {
  if (err == null) return 'Unknown error';
  if (typeof err === 'string') return err.trim() || 'Unknown error';

  if (err instanceof Error) {
    const extra = readSupabaseFields(err as unknown as Record<string, unknown>);
    return withMigrationHint(joinParts(err.message, extra), err.message, extra);
  }

  if (typeof err === 'object') {
    const obj = err as Record<string, unknown>;
    const message = readString(obj.message) ?? readString(obj.error_description);
    const extra = readSupabaseFields(obj);
    if (message) {
      return withMigrationHint(joinParts(message, extra), message, extra);
    }
    try {
      return JSON.stringify(err);
    } catch {
      return 'Unknown error';
    }
  }

  return String(err);
}

function readString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function readSupabaseFields(obj: Record<string, unknown>): {
  code: string | null;
  details: string | null;
  hint: string | null;
} {
  return {
    code: readString(obj.code),
    details: readString(obj.details),
    hint: readString(obj.hint),
  };
}

function joinParts(
  message: string,
  extra: { code: string | null; details: string | null; hint: string | null },
): string {
  const parts = [message];
  if (extra.code) parts.push(`code ${extra.code}`);
  if (extra.details && extra.details !== message) parts.push(extra.details);
  if (extra.hint && extra.hint !== message && extra.hint !== extra.details) {
    parts.push(extra.hint);
  }
  return parts.join(' — ');
}

/** Missing Phase 5 schema usually surfaces as undefined column `clinic_id`. */
function withMigrationHint(
  formatted: string,
  message: string,
  extra: { code: string | null; details: string | null; hint: string | null },
): string {
  const blob = [message, extra.code, extra.details, extra.hint]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  const looksLikeMissingClinicId =
    blob.includes('clinic_id') &&
    (blob.includes('does not exist') ||
      blob.includes('undefined column') ||
      extra.code === '42703' ||
      blob.includes('schema cache'));

  if (!looksLikeMissingClinicId) return formatted;

  return `${formatted} Run the Phase 5 migration (profiles.clinic_id) — see docs/phase5-path-c-portal.md.`;
}
