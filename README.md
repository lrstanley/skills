<!-- template:define:options
{
  "nodescription": true
}
-->

# Personal Agent Skills

<!-- template:begin:header -->
<!-- do not edit anything in this "template" block, its auto-generated -->

<p align="center">
  <a href="https://github.com/lrstanley/skills/tags">
    <img title="Latest Semver Tag" src="https://img.shields.io/github/v/tag/lrstanley/skills?style=flat-square">
  </a>
  <a href="https://github.com/lrstanley/skills/commits/master">
    <img title="Last commit" src="https://img.shields.io/github/last-commit/lrstanley/skills?style=flat-square">
  </a>



  <a href="https://codecov.io/gh/lrstanley/skills">
    <img title="Code Coverage" src="https://img.shields.io/codecov/c/github/lrstanley/skills/master?style=flat-square">
  </a>

</p>
<p align="center">
  <a href="https://github.com/lrstanley/skills/issues?q=is:open+is:issue+label:bug">
    <img title="Bug reports" src="https://img.shields.io/github/issues/lrstanley/skills/bug?label=issues&style=flat-square">
  </a>
  <a href="https://github.com/lrstanley/skills/issues?q=is:open+is:issue+label:enhancement">
    <img title="Feature requests" src="https://img.shields.io/github/issues/lrstanley/skills/enhancement?label=feature%20requests&style=flat-square">
  </a>
  <a href="https://github.com/lrstanley/skills/pulls">
    <img title="Open Pull Requests" src="https://img.shields.io/github/issues-pr/lrstanley/skills?label=prs&style=flat-square">
  </a>
  <a href="https://github.com/lrstanley/skills/discussions/new?category=q-a">
    <img title="Ask a Question" src="https://img.shields.io/badge/support-ask_a_question!-blue?style=flat-square">
  </a>
  <a href="https://liam.sh/chat"><img src="https://img.shields.io/badge/discord-bytecord-blue.svg?style=flat-square" title="Discord Chat"></a>
</p>
<!-- template:end:header -->

This repository is a single [Agent Plugin](https://agent-plugins.org/) (the repository root is
the plugin root, see [plugin.json](plugin.json)), bundling skills I've tailored to my personal
usecases/workflows, and/or that I simply use frequently. See the [remotes.yaml](remotes.yaml) file
for where some of these skills are sourced from.

## :package: Installation

### Cursor

This repository is also a Cursor marketplace containing a single plugin, so it can be added by
URL and then installed from Customize (user or project scope):

```bash
agent plugin marketplace add https://github.com/lrstanley/skills

# after pushing changes, re-index the marketplace to pick them up
agent plugin marketplace update lrstanley
```

### Other clients

Check [the compatible clients list](https://agent-plugins.org/compatible-clients) for how your
client installs or loads Agent Plugins from a git repository or a local directory.

### Local development

From a local clone (requires `jq`; override the plugins location with `AGENT_PLUGINS_HOME`):

```bash
git clone https://github.com/lrstanley/skills.git ~/go/src/github.com/lrstanley/skills
cd ~/go/src/github.com/lrstanley/skills

task # or: ./.github/scripts/install-symlinks.sh
```

This symlinks the repo into `~/.agents/plugins/lrstanley-skills`. If the Cursor `agent` CLI is
installed, it also adds the Cursor marketplace above (or re-indexes it if already added). Cursor
indexes from the git remote, so push changes first, and install the plugin itself from Customize.
Cursor does not read `~/.agents/plugins`, and ignores symlinks in `~/.cursor/plugins/local` that
point outside of that directory.

### Individual skills

If your client does not support Agent Plugins yet, skills can still be installed individually
from the [`skills/`](skills) directory with [skills.sh](https://skills.sh/lrstanley/skills):

```bash
npx skills add lrstanley/skills -g

# specific skill, with auto-accept (default agent checks)
npx skills add lrstanley/skills -s golang -g -y
```

## :wrench: Layout

```text
.
├── plugin.json          # plugin manifest (Agent Plugins spec v1.0.0)
├── .cursor-plugin/      # Cursor plugin + marketplace manifests (enables agents, rules, etc)
├── skills/              # one directory per skill, each containing a SKILL.md
├── agents/              # Cursor custom agents
├── remotes.yaml         # skills synced from upstream repositories (see `task sync`)
└── .github/             # sync/install scripts, patches, and repository tooling
```

## :brain: Skills

| Skill | Summary |
| --- | --- |
| [golang](skills/golang/SKILL.md) | Idiomatic Go for applications, APIs, CLIs, and performance work -- concurrency, testing, HTTP, errors, tracing, and logging. |
| [golang-packages](skills/golang-packages/SKILL.md) | Query pkg.go.dev for package and module metadata via pkgsite-cli or the v1beta REST API -- search, versions, symbols, vulnerabilities, and licenses. |
| [golang-tui](skills/golang-tui/SKILL.md) | Expert TUI development with Charm libraries (Bubble Tea, Lip Gloss, Bubbles) -- Elm Architecture, theming, composition, and terminal standards. |
| [grill-me](skills/grill-me/SKILL.md) | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. |
| [handoff](skills/handoff/SKILL.md) | Compact the current conversation into a handoff document for another agent to continue the work from a clean context. |
| [documentation-writer](skills/documentation-writer/SKILL.md) | Diataxis-guided technical documentation -- tutorials, how-to guides, reference, and explanations with audience-first structure. |
| [nuclear-review](skills/nuclear-review/SKILL.md) | Extremely strict maintainability review for abstraction quality, giant files, and spaghetti-condition growth -- ambitious structural simplification. |
| [pr-review-canvas](skills/pr-review-canvas/SKILL.md) | Interactive HTML PR review walkthrough from a GitHub PR URL -- fetches diffs, categorizes core vs mechanical changes, and renders annotated diffs. |
| [karpathy-guidelines](skills/karpathy-guidelines/SKILL.md) | Behavioral guidelines to reduce common LLM coding mistakes when writing, reviewing, or refactoring code. |
| [frontend-design](skills/frontend-design/SKILL.md) | Distinctive, production-grade frontend interfaces that avoid generic AI aesthetics. |
| [shadcn-vue](skills/shadcn-vue/SKILL.md) | Manage shadcn-vue components and projects -- adding, searching, fixing, debugging, styling, and composing UI. |
| [remotion-best-practices](skills/remotion-best-practices/SKILL.md) | Best practices for Remotion video creation in React. |
| [mermaid-diagrams](skills/mermaid-diagrams/SKILL.md) | Create software diagrams with Mermaid -- sequence, flowcharts, ERD, C4, and more. |
| [kubernetes-specialist](skills/kubernetes-specialist/SKILL.md) | Deploy and manage Kubernetes workloads -- manifests, Helm, RBAC, debugging, and GitOps. |
| [tui-design](skills/tui-design/SKILL.md) | Terminal UI design patterns -- layouts, color schemes, keyboard navigation, and dashboards. |
| [unslop](skills/unslop/SKILL.md) | Cut AI tells from writing by detecting and rewriting common AI-generated patterns. |
| [security-audit](skills/security-audit/SKILL.md) | Security guidance and vulnerability review for codebases, APIs, services, CLI tools, libraries, and daemons. |
| [simplify](skills/simplify/SKILL.md) | Scoped simplification via parallel quality, performance, and reuse review -- targeted cleanup on diffs or explicit scope with a fixed/skipped summary. |

<!-- template:begin:support -->
<!-- do not edit anything in this "template" block, its auto-generated -->
## :raising_hand_man: Support & Assistance

* :heart: Please review the [Code of Conduct](.github/CODE_OF_CONDUCT.md) for
     guidelines on ensuring everyone has the best experience interacting with
     the community.
* :raising_hand_man: Take a look at the [support](.github/SUPPORT.md) document on
     guidelines for tips on how to ask the right questions.
* :lady_beetle: For all features/bugs/issues/questions/etc, [head over here](https://github.com/lrstanley/skills/issues/new/choose).
<!-- template:end:support -->

<!-- template:begin:contributing -->
<!-- do not edit anything in this "template" block, its auto-generated -->
## :handshake: Contributing

* :heart: Please review the [Code of Conduct](.github/CODE_OF_CONDUCT.md) for guidelines
     on ensuring everyone has the best experience interacting with the
    community.
* :clipboard: Please review the [contributing](.github/CONTRIBUTING.md) doc for submitting
     issues/a guide on submitting pull requests and helping out.
* :old_key: For anything security related, please review this repositories [security policy](https://github.com/lrstanley/skills/security/policy).
<!-- template:end:contributing -->

<!-- template:begin:license -->
<!-- do not edit anything in this "template" block, its auto-generated -->
## :balance_scale: License

```
MIT License

Copyright (c) 2026 Liam Stanley <liam@liam.sh>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

_Also located [here](LICENSE)_
<!-- template:end:license -->
