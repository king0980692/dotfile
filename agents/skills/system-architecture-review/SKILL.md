---
name: system-architecture-review
description: Review an existing codebase's system architecture using code-review-graph and source evidence; produce academic overview and detailed flow diagrams with actionable findings.
---

# System Architecture Review

Use this skill when the user wants to understand or assess the architecture of an existing repository. Combine the structural graph from [code-review-graph](https://github.com/tirth8205/code-review-graph) with direct inspection of code, configuration, infrastructure definitions, and tests. The graph finds leads; the repository evidence supports the conclusions. For a diagram from a supplied description without a codebase, use the `architecture-diagram` skill instead.

The result has two reading depths: a compact system overview and a technical review that an engineer can verify. Use the academic visual system in [assets/academic-diagram-template.html](assets/academic-diagram-template.html); adapt every example node, label, boundary, caption, and note to the actual system.

## Review method

1. Establish the repository root and the question the review should answer. If no focus is given, cover the main user-facing path, state ownership, external integrations, and the most consequential architectural risks. Record the reviewed revision and what is outside scope.
2. Read [references/code-review-graph.md](references/code-review-graph.md) and follow its graph workflow. Start with `get_minimal_context_tool`, then build or update the local index if absent or stale. Use compact architecture, community, and flow queries to choose where to inspect. Use hub, bridge, coupling, gap, and change-impact tools only for questions they can answer.
3. Verify the selected paths in source files and check infrastructure and deployment artifacts separately. A static import or call edge is not proof of a runtime service connection; a graph community is not a deployed service. Trace entry point → handler → application logic → data or external dependency, noting where the chain becomes uncertain. Inspect relevant tests, but do not equate a graph test edge with adequate coverage.
4. Form a system model at two levels. The overview groups components by responsibility and shows one representative path. Detail figures show named entry points, code or service boundaries, handoffs, state changes, and failure or trust boundaries supported by evidence. Preserve consistent names between levels. If one detailed figure becomes crowded, split by flow rather than shrinking labels.
5. Assess consequences, not just structure. A finding needs a mechanism, affected path, evidence, and a practical next step. Centrality, surprise scores, and missing graph edges are leads, not findings by themselves. Include material strengths and unknowns as well as risks.

For each detailed path, record the trigger, code entry point, ordered handoffs, inputs and outputs, state reads or writes, external calls, authorization checks, failure behavior, and relevant tests. Include only details supported by evidence; mark the rest unknown. At the system level, examine component ownership, coupling across boundaries, data ownership, reliability and recovery, security boundaries, deployment mapping, and observability where the repository provides evidence. This trace is the substance behind the figures, not a list of tool scores.

## Evidence standard

- Label claims as **confirmed** (direct code/config/test evidence), **graph-derived** (a structural lead), or **inferred** (a reasoned interpretation). Cite repository paths and line numbers for nontrivial claims. Show missing deployment or runtime evidence explicitly.
- For GCP, AWS, or Azure diagrams, name a resource, region, VPC, IAM boundary, protocol, or data route only when the repository or supplied documentation supports it. Inspect Terraform, manifests, service configuration, API specifications, and operational docs where available; do not derive cloud topology from function calls alone.
- Explain what the system does in plain language before diving into classes and functions. Expand acronyms at first use. Keep source identifiers in the detail view and evidence table so an engineer can follow the trail.

## Deliverables

Unless the user specifies another format, save an `architecture-review.md` and two or more HTML/SVG figures in the requested output location, or in an `architecture-review/` directory at the repository root:

1. **Overview figure:** the core responsibilities, real system boundaries, and main flow. A newcomer should understand it quickly.
2. **Detail figure(s):** at least one traced critical path with actual interfaces, code or service owners, data stores, and external handoffs when verified. Mark uncertain or inferred edges visibly.
3. **Review report:** scope and revision; a short system explanation; an evidence table linking figure nodes and edges to `path:line`; a step-by-step technical trace for each detailed figure; prioritized findings with consequence, evidence, confidence, and recommendation; coverage limits and open questions. Link each figure from the report.

Use restrained colors, generous spacing, readable labels, and descriptive captions. Retain the template's export controls if using it. Before delivery, verify that the figures and report agree, every significant edge has evidence or an uncertainty label, and the HTML/SVG opens and parses. If graph analysis was unavailable or partial, state exactly which conclusions rely only on manual inspection.
