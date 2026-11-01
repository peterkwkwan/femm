/**
 * extract-lab-pdf — Phase 2 callable Edge Function.
 *
 * Body: { "document_id": "<uuid>" }
 * Auth: Bearer user JWT (anon key + session). Uses caller's RLS.
 *
 * Downloads the PDF from private lab-pdfs Storage, extracts biomarker rows,
 * replaces lab_biomarker_rows for that document, sets status=extracted.
 */

import { createClient } from "npm:@supabase/supabase-js@2.49.1";
import { extractPdfTextTokens } from "./pdf_text.ts";
import { parseLabTableTokens } from "./parse_lab_table.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "POST required" }, 405);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      return json({ error: "Missing SUPABASE_URL / SUPABASE_ANON_KEY" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization bearer token" }, 401);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null) as
      | { document_id?: string }
      | null;
    const documentId = body?.document_id;
    if (!documentId || typeof documentId !== "string") {
      return json({ error: "document_id required" }, 400);
    }

    const { data: doc, error: docError } = await supabase
      .from("lab_documents")
      .select("id, user_id, storage_path, status")
      .eq("id", documentId)
      .maybeSingle();

    if (docError) {
      return json({ error: docError.message }, 400);
    }
    if (!doc || doc.user_id !== user.id) {
      return json({ error: "Document not found" }, 404);
    }

    await supabase
      .from("lab_documents")
      .update({
        status: "extracting",
        extract_error: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", documentId);

    const { data: fileBlob, error: downloadError } = await supabase.storage
      .from("lab-pdfs")
      .download(doc.storage_path);

    if (downloadError || !fileBlob) {
      await markFailed(supabase, documentId, downloadError?.message ?? "Download failed");
      return json({ error: downloadError?.message ?? "Download failed" }, 400);
    }

    const pdfBytes = new Uint8Array(await fileBlob.arrayBuffer());
    let extract;
    try {
      const tokens = await extractPdfTextTokens(pdfBytes);
      extract = parseLabTableTokens(tokens);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await markFailed(supabase, documentId, message);
      return json({ error: message }, 422);
    }

    // Replace prior extract rows for this document
    const { error: deleteError } = await supabase
      .from("lab_biomarker_rows")
      .delete()
      .eq("lab_document_id", documentId);
    if (deleteError) {
      await markFailed(supabase, documentId, deleteError.message);
      return json({ error: deleteError.message }, 400);
    }

    const now = new Date().toISOString();
    const rows = extract.biomarkers.map((b, index) => ({
      lab_document_id: documentId,
      user_id: user.id,
      sort_order: index,
      name: b.name,
      value: b.value,
      unit: b.unit,
      ref_range: b.ref_range,
      flag: b.flag,
      is_deleted: false,
      updated_at: now,
    }));

    const { data: inserted, error: insertError } = await supabase
      .from("lab_biomarker_rows")
      .insert(rows)
      .select(
        "id, sort_order, name, value, unit, ref_range, flag, is_deleted",
      );

    if (insertError) {
      await markFailed(supabase, documentId, insertError.message);
      return json({ error: insertError.message }, 400);
    }

    const { error: updateError } = await supabase
      .from("lab_documents")
      .update({
        status: "extracted",
        extract_error: null,
        extracted_at: now,
        updated_at: now,
      })
      .eq("id", documentId);

    if (updateError) {
      return json({ error: updateError.message }, 400);
    }

    return json({
      document_id: documentId,
      status: "extracted",
      report: extract.report,
      biomarkers: inserted ?? rows,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function markFailed(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  documentId: string,
  message: string,
): Promise<void> {
  await supabase
    .from("lab_documents")
    .update({
      status: "failed",
      extract_error: message,
      updated_at: new Date().toISOString(),
    })
    .eq("id", documentId);
}
