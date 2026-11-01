/**
 * Minimal PDF text extractor for simple ReportLab-style lab panels.
 * Pure Deno — no canvas / native deps (Supabase Edge free tier friendly).
 * Handles content streams with /ASCII85Decode /FlateDecode (and Flate-only).
 */

const WINANSI_MAP: Record<number, string> = {
  0x80: "€",
  0x82: "‚",
  0x83: "ƒ",
  0x84: "„",
  0x85: "…",
  0x86: "†",
  0x87: "‡",
  0x88: "ˆ",
  0x89: "‰",
  0x8a: "Š",
  0x8b: "‹",
  0x8c: "Œ",
  0x91: "‘",
  0x92: "’",
  0x93: "“",
  0x94: "”",
  0x95: "•",
  0x96: "–",
  0x97: "—",
  0x98: "˜",
  0x99: "™",
  0x9a: "š",
  0x9b: "›",
  0x9c: "œ",
  0x9f: "Ÿ",
};

function decodePdfLiteral(raw: string): string {
  let out = "";
  for (let i = 0; i < raw.length; i++) {
    const ch = raw[i];
    if (ch !== "\\") {
      const code = raw.charCodeAt(i);
      out += WINANSI_MAP[code] ?? ch;
      continue;
    }
    i++;
    if (i >= raw.length) break;
    const esc = raw[i];
    if (esc === "n") out += "\n";
    else if (esc === "r") out += "\r";
    else if (esc === "t") out += "\t";
    else if (esc === "b") out += "\b";
    else if (esc === "f") out += "\f";
    else if (esc === "(" || esc === ")" || esc === "\\") out += esc;
    else if (esc >= "0" && esc <= "7") {
      let oct = esc;
      for (let k = 0; k < 2 && i + 1 < raw.length; k++) {
        const n = raw[i + 1];
        if (n < "0" || n > "7") break;
        oct += n;
        i++;
      }
      const code = Number.parseInt(oct, 8);
      out += WINANSI_MAP[code] ?? String.fromCharCode(code);
    } else {
      out += esc;
    }
  }
  return out;
}

function ascii85Decode(data: Uint8Array): Uint8Array {
  const filtered: number[] = [];
  for (const b of data) {
    if (b === 0x7e /* ~ */) break;
    if (b === 0x20 || b === 0x09 || b === 0x0a || b === 0x0d || b === 0x00) {
      continue;
    }
    filtered.push(b);
  }

  const out: number[] = [];
  let i = 0;
  while (i < filtered.length) {
    if (filtered[i] === 0x7a /* z */) {
      out.push(0, 0, 0, 0);
      i++;
      continue;
    }
    const remain = filtered.length - i;
    const take = Math.min(5, remain);
    const chunk = filtered.slice(i, i + take);
    const pad = 5 - take;
    while (chunk.length < 5) chunk.push(0x75 /* u */);
    let n = 0;
    for (const c of chunk) {
      n = n * 85 + (c - 33);
    }
    const bytes = [
      (n >>> 24) & 0xff,
      (n >>> 16) & 0xff,
      (n >>> 8) & 0xff,
      n & 0xff,
    ];
    out.push(...bytes.slice(0, 4 - pad));
    i += take;
  }
  return new Uint8Array(out);
}

async function inflateZlib(data: Uint8Array): Promise<Uint8Array> {
  const ds = new DecompressionStream("deflate");
  const stream = new Blob([data]).stream().pipeThrough(ds);
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

type StreamFilter = "ASCII85Decode" | "FlateDecode" | "Other";

interface ContentStream {
  filters: StreamFilter[];
  bytes: Uint8Array;
}

function parseFilters(dict: string): StreamFilter[] {
  const filters: StreamFilter[] = [];
  const arrayMatch = dict.match(/\/Filter\s*\[([^\]]*)\]/);
  const singleMatch = dict.match(/\/Filter\s*\/(\w+)/);
  const raw = arrayMatch?.[1] ?? (singleMatch ? `/${singleMatch[1]}` : "");
  for (const m of raw.matchAll(/\/(\w+)/g)) {
    const name = m[1];
    if (name === "ASCII85Decode" || name === "FlateDecode") {
      filters.push(name);
    } else {
      filters.push("Other");
    }
  }
  return filters;
}

function findContentStreams(pdf: Uint8Array): ContentStream[] {
  const latin1 = new TextDecoder("latin1").decode(pdf);
  const streams: ContentStream[] = [];
  const objRe = /\d+\s+\d+\s+obj[\s\S]*?endobj/g;
  let objMatch: RegExpExecArray | null;
  while ((objMatch = objRe.exec(latin1))) {
    const objText = objMatch[0];
    const streamIdx = objText.search(/stream\r?\n/);
    if (streamIdx < 0) continue;
    const dict = objText.slice(0, streamIdx);
    if (!/\/Filter/.test(dict) && !/\/Length\s+\d+/.test(dict)) continue;
    // Prefer page content streams (have Filter) over xref-ish binaries
    const filters = parseFilters(dict);
    if (filters.length === 0) continue;
    if (filters.includes("Other")) continue;

    const headerMatch = objText.slice(streamIdx).match(/^stream\r?\n/);
    if (!headerMatch) continue;
    const localStart = streamIdx + headerMatch[0].length;
    const endRel = objText.indexOf("endstream", localStart);
    if (endRel < 0) continue;

    const absStart = objMatch.index + localStart;
    let absEnd = objMatch.index + endRel;
    // Trim one trailing newline before endstream
    if (pdf[absEnd - 1] === 0x0a) absEnd--;
    if (pdf[absEnd - 1] === 0x0d) absEnd--;

    streams.push({
      filters,
      bytes: pdf.subarray(absStart, absEnd),
    });
  }
  return streams;
}

async function decodeStream(stream: ContentStream): Promise<string> {
  let bytes = stream.bytes;
  for (const filter of stream.filters) {
    if (filter === "ASCII85Decode") {
      bytes = ascii85Decode(bytes);
    } else if (filter === "FlateDecode") {
      bytes = await inflateZlib(bytes);
    }
  }
  return new TextDecoder("latin1").decode(bytes);
}

/** Extract Tj / TJ string operands in drawing order. */
export function extractTjStrings(content: string): string[] {
  const out: string[] = [];
  const re = /\((?:\\.|[^\\)])*\)\s*Tj|\[(.*?)\]\s*TJ/gs;
  let m: RegExpExecArray | null;
  while ((m = re.exec(content))) {
    if (m[0].endsWith("Tj")) {
      const lit = m[0].match(/^\((?:\\.|[^\\)])*\)/)?.[0];
      if (!lit) continue;
      out.push(decodePdfLiteral(lit.slice(1, -1)));
    } else {
      const arr = m[1] ?? "";
      for (const lit of arr.matchAll(/\((?:\\.|[^\\)])*\)/g)) {
        out.push(decodePdfLiteral(lit[0].slice(1, -1)));
      }
    }
  }
  return out;
}

/** Decode PDF bytes → ordered text tokens (ReportLab lab table friendly). */
export async function extractPdfTextTokens(pdfBytes: Uint8Array): Promise<string[]> {
  const streams = findContentStreams(pdfBytes);
  if (streams.length === 0) {
    throw new Error("No decodable PDF content streams found");
  }
  const tokens: string[] = [];
  for (const stream of streams) {
    const content = await decodeStream(stream);
    tokens.push(...extractTjStrings(content));
  }
  return tokens.map((t) => t.trim()).filter((t) => t.length > 0);
}

export async function extractPdfPlainText(pdfBytes: Uint8Array): Promise<string> {
  return (await extractPdfTextTokens(pdfBytes)).join("\n");
}
