/**
 * Parse biomarker rows from ordered PDF text tokens.
 * Expects a table header: Test | Result | Unit | Reference Range | Flag
 * Flags are H/L only when present as the 5th column — never invented.
 */

export type BiomarkerFlag = "H" | "L" | null;

export interface BiomarkerRow {
  name: string;
  value: number | null;
  unit: string | null;
  ref_range: string | null;
  flag: BiomarkerFlag;
}

export interface LabExtractResult {
  report: {
    lab_name: string | null;
    title: string | null;
    report_id: string | null;
    patient_name: string | null;
  };
  biomarkers: BiomarkerRow[];
}

function parseNumber(raw: string): number | null {
  const cleaned = raw.replace(/,/g, "").trim();
  if (!/^[+-]?\d+(\.\d+)?$/.test(cleaned)) return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

function isFlagToken(token: string): token is "H" | "L" {
  return token === "H" || token === "L";
}

function findHeaderIndex(tokens: string[]): number {
  for (let i = 0; i < tokens.length - 4; i++) {
    if (
      tokens[i] === "Test" &&
      tokens[i + 1] === "Result" &&
      tokens[i + 2] === "Unit" &&
      tokens[i + 3] === "Reference Range" &&
      tokens[i + 4] === "Flag"
    ) {
      return i;
    }
  }
  throw new Error("Lab table header (Test/Result/Unit/Reference Range/Flag) not found");
}

function metaValue(tokens: string[], label: string): string | null {
  const idx = tokens.findIndex((t) => t === label || t.startsWith(label));
  if (idx < 0) return null;
  if (tokens[idx].includes(":") && tokens[idx].length > label.length + 1) {
    return tokens[idx].split(":").slice(1).join(":").trim() || null;
  }
  const next = tokens[idx + 1];
  return next?.trim() || null;
}

export function parseLabTableTokens(tokens: string[]): LabExtractResult {
  const headerIdx = findHeaderIndex(tokens);
  const preamble = tokens.slice(0, headerIdx);

  let endIdx = tokens.findIndex((t, i) => i > headerIdx && t.startsWith("Flags:"));
  if (endIdx < 0) {
    endIdx = tokens.findIndex(
      (t, i) => i > headerIdx && t.startsWith("Reference intervals"),
    );
  }
  if (endIdx < 0) endIdx = tokens.length;

  const body = tokens.slice(headerIdx + 5, endIdx);
  const biomarkers: BiomarkerRow[] = [];
  let i = 0;
  while (i < body.length) {
    // Need at least name, value, unit, ref
    if (i + 3 >= body.length) break;
    const name = body[i++];
    const valueToken = body[i++];
    const unit = body[i++];
    const ref_range = body[i++];
    let flag: BiomarkerFlag = null;
    if (i < body.length && isFlagToken(body[i])) {
      flag = body[i++];
    }
    biomarkers.push({
      name,
      value: parseNumber(valueToken),
      unit: unit || null,
      ref_range: ref_range || null,
      flag,
    });
  }

  if (biomarkers.length === 0) {
    throw new Error("No biomarker rows parsed from lab table");
  }

  return {
    report: {
      lab_name: preamble[0] ?? null,
      title: preamble[1] ?? null,
      report_id: metaValue(preamble, "Report ID:") ?? metaValue(preamble, "Report ID"),
      patient_name:
        metaValue(preamble, "Patient Name:") ?? metaValue(preamble, "Patient Name"),
    },
    biomarkers,
  };
}

/** Compare extract vs golden fixture within accepted prototype tolerance. */
export function compareToGolden(
  actual: BiomarkerRow[],
  golden: BiomarkerRow[],
  opts: { valueEpsilon?: number } = {},
): { ok: boolean; errors: string[] } {
  const valueEpsilon = opts.valueEpsilon ?? 1e-6;
  const errors: string[] = [];
  if (actual.length !== golden.length) {
    errors.push(`row count ${actual.length} != golden ${golden.length}`);
  }
  const n = Math.min(actual.length, golden.length);
  for (let i = 0; i < n; i++) {
    const a = actual[i];
    const g = golden[i];
    if (a.name !== g.name) errors.push(`[${i}] name: ${JSON.stringify(a.name)} != ${JSON.stringify(g.name)}`);
    if (a.unit !== g.unit) errors.push(`[${i}] unit: ${JSON.stringify(a.unit)} != ${JSON.stringify(g.unit)}`);
    if (a.ref_range !== g.ref_range) {
      errors.push(
        `[${i}] ref_range: ${JSON.stringify(a.ref_range)} != ${JSON.stringify(g.ref_range)}`,
      );
    }
    if (a.flag !== g.flag) {
      errors.push(`[${i}] flag: ${JSON.stringify(a.flag)} != ${JSON.stringify(g.flag)}`);
    }
    if (a.value === null || g.value === null) {
      if (a.value !== g.value) {
        errors.push(`[${i}] value: ${a.value} != ${g.value}`);
      }
    } else if (Math.abs(a.value - g.value) > valueEpsilon) {
      errors.push(`[${i}] value: ${a.value} != ${g.value}`);
    }
  }
  return { ok: errors.length === 0, errors };
}
