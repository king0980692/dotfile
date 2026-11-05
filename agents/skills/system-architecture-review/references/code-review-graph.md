# Code-review-graph workflow for architecture review

Use the installed `code-review-graph` MCP tools when available. Pass the explicit `repo_root` to every repository-specific call; the MCP server's own working directory may be a different project. Follow the live tool schemas if they differ from these examples. The [upstream user guide](https://github.com/tirth8205/code-review-graph/blob/staging/docs/USAGE.md) and [README](https://github.com/tirth8205/code-review-graph) describe the graph's capabilities and limits.

## Discover and refresh

1. Call `get_minimal_context_tool(task="system architecture review", repo_root=...)` first. It gives compact graph status and suggested next queries. If it reports no graph, call `build_or_update_graph_tool(repo_root=..., full_rebuild=true)` once. If the index exists but is stale, call the same tool for an incremental update. Do not rebuild repeatedly.
2. Check `list_graph_stats_tool(repo_root=...)` for indexed files, languages, last update, and parse status. If a build is partial, record the failed files and do not make completeness claims about those areas.
3. If the MCP tools are unavailable but the CLI is installed, use `code-review-graph build` or `update` and `status` from the target repository, then inspect source manually. `visualize --format json` can expose graph structure; its raw file/function network is supporting data, not the final system diagram. If neither interface works, continue with direct repository inspection and disclose that graph analysis was unavailable.

## Build an evidence map

- Call `get_architecture_overview_tool(detail_level="minimal", repo_root=...)` and `list_communities_tool(detail_level="minimal", repo_root=...)` to find likely modules and cross-community coupling. Community labels are clustering results, not proven service boundaries.
- Call `list_flows_tool(detail_level="minimal", repo_root=...)` to identify candidate entry paths. For a representative path, call `get_flow_tool` for its steps and source locations, then read the actual files. Flow detection may miss dynamic calls and varies by language; absence from the graph is not proof that no path exists.
- Use `query_graph_tool` and `semantic_search_nodes_tool` for targeted questions: endpoints and handlers, callers and callees, importers, publishers/listeners, tests, or file summaries. For a large dependency chain, use `traverse_graph_tool` with a small depth and token budget, then open only the relevant files.
- Examine manifests, infrastructure as code, API definitions, migrations, configuration, CI, and operational documentation outside the graph as needed. The graph indexes some Terraform and language-specific config, but does not establish actual deployment state, secret values, network reachability, or production traffic.

## Probe architecture risks

Use these tools after establishing the principal paths, and only for relevant questions:

| Question | Graph tools | Confirmation needed |
| --- | --- | --- |
| Where are shared dependencies or chokepoints? | `get_hub_nodes_tool`, `get_bridge_nodes_tool` | Inspect callers, ownership, failure handling, and actual path impact. |
| Is there surprising cross-module coupling? | `get_surprising_connections_tool`, `get_architecture_overview_tool` | Read both sides of the connection and verify its purpose. |
| Are critical parts poorly tested or isolated? | `get_knowledge_gaps_tool`, `query_graph_tool(pattern="tests_for")` | Read tests and assess assertions, not just their existence. |
| What changes would affect a path? | `detect_changes_tool`, `get_affected_flows_tool`, `get_impact_radius_tool` | Use only for a change or PR review; confirm the diff and affected behavior. |

Graph scores and edges are prompts for investigation. Report an architectural issue only after identifying its mechanism and consequence in the real system. Distinguish static edges marked extracted or inferred by the tool from directly confirmed runtime behavior.

## Turn evidence into the review

Create an evidence table before drawing the detailed figures:

| Element or claim | Evidence | Status | Why it matters |
| --- | --- | --- | --- |
| Entry point routes requests to an application handler | `src/server.py:42`, `src/routes.py:18` | Confirmed | Establishes the start of the main flow. |
| Module A depends on module B | graph edge; inspect both source files | Graph-derived until checked | Candidate coupling or change impact. |
| Service runs in a particular GCP region | deployment artifact or supplied ops doc required | Unknown until verified | Region placement affects the cloud diagram. |

Use actual repository paths and lines; the rows above illustrate the format only. In the report, write a plain-language explanation first, then a step-by-step technical trace with file links. For each finding, give severity or priority, consequence, evidence, confidence, and the smallest useful validation or design change. Include an explicit unknowns section so the review does not turn missing evidence into false certainty.
