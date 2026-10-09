# Segmentation prompt — lecture transcript → topic/problem boundaries

You are a specialist model. Your ONLY job: split a timestamped lecture
transcript chunk into topic and problem segments and return them as JSON.

/no_think

## Input

Transcript chunk covering seconds {{CHUNK_START}} to {{CHUNK_END}}.
Each line starts with [mm:ss] followed by what the lecturer said.

{{TRANSCRIPT}}

## Rules

1. Output ONLY the JSON object. No explanations, no markdown fences,
   no preamble, no trailing text. The response must start with `{`
   and end with `}`.
2. Every segment needs: "type" ("topic" or "problem"), a short "title"
   (max 8 words), "start" and "end" in WHOLE SECONDS.
3. "start" and "end" must lie inside [{{CHUNK_START}}, {{CHUNK_END}}],
   with start < end.
4. Segments must be sorted by start time and must NOT overlap.
5. Cover the whole chunk with no gaps: the first segment starts at
   {{CHUNK_START}} and each segment's start equals the previous end,
   except the last segment which ends at {{CHUNK_END}}.
6. Mark a segment "problem" only when the lecturer solves a worked
   example, numerical, or exercise. Everything else is "topic".
7. Keep titles specific: name the concept or the problem being solved.

## Output format (exactly this shape)

{"segments":[{"type":"topic","title":"...","start":0,"end":95},{"type":"problem","title":"...","start":95,"end":210}]}
