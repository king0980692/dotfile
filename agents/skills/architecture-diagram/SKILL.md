---
name: architecture-diagram
description: Create representative academic-style system, cloud, infrastructure, security, or network architecture diagrams that explain the big picture and preserve essential technical detail.
---

# Architecture Diagram

Create a clear architecture figure suitable for a paper, technical report, or presentation. Start from [resources/template.html](resources/template.html). Use the user's provider, terminology, and architecture; the template is only a generic example.

## Choose the abstraction

Before drawing, identify the audience, the system's purpose, the main flow, important boundaries, and the components that make this system distinctive. If the audience is unspecified, make an overview that a technically literate newcomer can understand and an engineer can still map to the real system.

- Choose one question for the figure to answer, such as how a request is served, how data moves, or where trust changes. Make that question evident in the title or caption. A diagram that tries to answer every question usually loses its main story.
- Show a small set of meaningful responsibilities or stages, usually about four to seven primary nodes. Group implementation components only when they share a role and the grouping does not conceal an important dependency, trust boundary, or failure mode. Use concrete, human-readable names such as “Application service” or “Operational data”; put product names in smaller secondary labels when they matter.
- Preserve the few details that explain the architecture: the principal path, state location, identity or trust boundary, and any asynchronous or external dependency that materially changes the system. Omit routine plumbing, repeated instances, ports, and deployment trivia from an overview unless they are the point of the figure.
- Use a representative path rather than drawing every possible path. State the scope and omitted variants in the caption or notes. Do not present an illustrative path as exhaustive, or imply a relationship, service, or boundary that the source does not support.
- If a necessary detail would overcrowd the overview, make a second detail figure rather than shrinking labels or filling the overview with extra boxes. Give both figures consistent terms and colors.

## Explain in layers

1. **First glance:** The title and primary node labels convey who uses the system, what it does, and where the result goes. The main arrows read in one clear direction.
2. **Closer look:** Secondary labels identify actual services or technologies; a few edge labels explain protocols or data types where those facts matter.
3. **Technical reading:** A short caption and notes explain the mechanism, the meaning of boundaries, and any assumptions or important omissions in plain language. Explain acronyms on first use. The caption should say what the reader learns, not merely list the boxes.

Check the abstraction against the source: can a newcomer explain the main path after one glance, and can an expert recognize the real system without being misled? If either answer is no, revise the grouping or wording.

## Visual style

- Use a warm white page (`#f8f8f6`), a white figure area, dark ink (`#263238`), and restrained gray rules (`#c8cfcd`). Avoid dark backgrounds, neon colors, gradients, glow, animated status indicators, and decorative grids.
- Use a serif title and figure caption; use a readable sans-serif for component labels, connections, legend, and notes. Keep labels at least 10–11 SVG units at the template's 1000-unit width. Use normal case rather than all caps for component names.
- Use thin, consistent strokes and light fills. Color is a secondary cue; labels and line styles must still distinguish parts in grayscale or print. Keep the legend compact and outside all cloud, network, or security boundaries.
- Use these muted component colors unless the user supplies a palette. All labels use dark ink, not white text.

| Component | Fill | Stroke |
| --- | --- | --- |
| Client / frontend | `#e9f0f2` | `#6d8894` |
| Application / backend | `#eaf0e9` | `#738a78` |
| Data / storage | `#f0edf2` | `#8b7d91` |
| Cloud / infrastructure | `#f2efe7` | `#988865` |
| Identity / security | `#f3ecea` | `#9a7b76` |
| Messaging | `#f2eee8` | `#9b896f` |
| External / generic | `#f0f2f1` | `#858f90` |

## Diagram rules

1. Arrange components in the direction of the principal flow. Use enough whitespace for labels and routes; aim for at least 32 SVG units between ordinary boxes. Expand the viewBox when needed. Make the primary path visually stronger than supporting flows.
2. Draw boundaries first, then connection lines, then component boxes and text. This keeps arrows behind nodes without obscuring labels. Use solid lines for ordinary data flow and dashed lines for identity, control, or optional flows; explain special line styles in the legend or caption.
3. Place connection labels near their lines without touching a box or another label. Route around nodes rather than through them. Use descriptive labels such as `HTTPS`, `SQL`, or `events` only when supported by the user's description.
4. Put the legend below the lowest boundary, with a visible gap. Do not suggest a region, VPC, subnet, security group, or trust boundary unless it is known or explicitly marked as an assumption.
5. Keep provider names accurate and provider-neutral when unspecified. For GCP, AWS, or Azure requests, replace the generic cloud example with the user's actual services and hierarchy; do not retain unrelated example services.

## Build the file

Copy and adapt `resources/template.html`. Treat its nodes as an example, not a checklist. Replace the title, subtitle, example nodes, connections, boundary, legend, caption, and notes with the selected story. Preserve the export toolbar and its `copyAsImage()`, `downloadPNG()`, and `downloadPDF()` functions. The diagram itself renders from embedded CSS and inline SVG; the export controls load pinned `html2canvas` and `jsPDF` scripts from a CDN. Preserve their versions and integrity attributes if keeping the controls.

Deliver one `.html` file that opens directly in a browser. Before delivery, check that labels are legible, lines do not cross nodes, the legend sits outside boundaries, the page prints on a light background, and the figure remains understandable in grayscale.
