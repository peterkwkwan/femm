/** Shared Path C / portal disclaimer copy (Phase 6 audit). */
export const PATH_C_DISCLAIMER =
  'Care-navigation only — not a diagnosis or medical advice.';

export const PORTAL_NOTE = 'Hong Kong prototype · English UI · not a diagnosis';

export function assertsNotDiagnosis(copy: string): boolean {
  const lower = copy.toLowerCase();
  return lower.includes('not a diagnosis') || lower.includes('care-navigation');
}
