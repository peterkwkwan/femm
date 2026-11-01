#!/usr/bin/env -S deno run --allow-read
/**
 * Offline golden-fixture test for Phase 2 lab PDF extract.
 *
 * Run from repo root:
 *   deno run --allow-read scripts/test-extract-fixture.ts
 *   npm run test:extract-fixture
 */

import { extractPdfTextTokens } from "../supabase/functions/extract-lab-pdf/pdf_text.ts";
import {
  compareToGolden,
  parseLabTableTokens,
  type BiomarkerRow,
} from "../supabase/functions/extract-lab-pdf/parse_lab_table.ts";

const ROOT = new URL("..", import.meta.url);
const PDF_PATH = new URL("fixtures/labs/synthetic-hk-womens-panel.pdf", ROOT);
const GOLDEN_PATH = new URL(
  "fixtures/labs/synthetic-hk-womens-panel.extract.json",
  ROOT,
);

const pdfBytes = await Deno.readFile(PDF_PATH);
const goldenJson = JSON.parse(await Deno.readTextFile(GOLDEN_PATH)) as {
  biomarkers: BiomarkerRow[];
};

const tokens = await extractPdfTextTokens(pdfBytes);
const extract = parseLabTableTokens(tokens);
const { ok, errors } = compareToGolden(extract.biomarkers, goldenJson.biomarkers);

console.log(`Parsed ${extract.biomarkers.length} biomarker rows`);
console.log(`Report: ${extract.report.lab_name} / ${extract.report.report_id}`);

if (!ok) {
  console.error("GOLDEN FIXTURE MISMATCH:");
  for (const e of errors) console.error(" -", e);
  Deno.exit(1);
}

console.log("OK — extract matches golden fixture within tolerance");
