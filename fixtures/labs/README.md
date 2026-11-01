# Lab fixtures (Phase 1)

| File | Role |
| --- | --- |
| `synthetic-hk-womens-panel.pdf` | Authored synthetic HK-style women’s panel for Path A upload demos |
| `synthetic-hk-womens-panel.extract.json` | Golden extract rows for Phase 2 Edge Function tests |

Regenerate PDF (keep golden JSON in sync if rows change):

```bash
pip install reportlab
npm run pdf:synthetic-lab
```

Offline Phase 2 extract test (Deno):

```bash
npm run test:extract-fixture
```

Not a real patient report. Flags only as printed on the PDF.
