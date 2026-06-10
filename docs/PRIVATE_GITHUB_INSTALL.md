# Private GitHub Install for CopilotOps

CopilotOps is intended to be used from a private GitHub repository by invited users.

Repository:

```text
https://github.com/hjahouse/CopilotOps
```

## Important

This access model does not require npm publishing.

Users can run CopilotOps with `npx` from the private GitHub repo after:

1. The GitHub repository is private.
2. The user is invited to the repository or a GitHub team with repository access.
3. The user is authenticated with GitHub in Git/VS Code.
4. Node.js and Git are installed.

The command itself does not grant access. Access is controlled by GitHub repository permissions.

## Admin Setup

1. Open the GitHub repository:

```text
https://github.com/hjahouse/CopilotOps
```

2. Confirm the repository visibility is Private.
3. Go to Settings -> Collaborators and teams.
4. Invite approved users or a GitHub team.
5. Ask users to accept the invite and authenticate Git on their machine.

## User Install

Run from inside a target project:

```bash
cd C:\SharedProjects\CS_Datafactory_v2
npx --yes git+https://github.com/hjahouse/CopilotOps.git#dev install --dry-run
```

If the dry-run looks correct:

```bash
npx --yes git+https://github.com/hjahouse/CopilotOps.git#dev install
```

Or run with an explicit target:

```bash
npx --yes git+https://github.com/hjahouse/CopilotOps.git#dev install --target C:\SharedProjects\CS_Datafactory_v2 --dry-run
```

## Diagnostics

Run:

```bash
npx --yes git+https://github.com/hjahouse/CopilotOps.git#dev doctor --target C:\SharedProjects\CS_Datafactory_v2
```

## Safety

The install command must not replace the whole `.github` folder.

It only links Copilot-specific assets:

* `.github/copilot-instructions.md`
* `.github/instructions`
* `.github/prompts`
* `.github/skills`

It must not touch:

* `.github/workflows`

## Not Supported In This Model

This private GitHub model does not support:

```bash
npx copilotops@latest install
```

That command requires publishing `copilotops` to the public npm registry.
