# CopilotOps Admin Setup

Use this file as the maintainer checklist for the private CopilotOps repo.

## Admin Checklist

1. Keep the GitHub repo private.
2. Invite approved users or a GitHub team.
3. Tell users to authenticate GitHub in Git or VS Code.
4. Ask users to run `install --dry-run` first.
5. Review warnings before real install.

## Branch Safety

Protect `dev` and `main` so collaborators cannot push directly.

Use branch protection or rulesets where available:

- Require pull requests before merging.
- Require approvals before merge.
- Prevent force pushes.
- Prevent deletions.
- Restrict who can push to the branch.

## Invitation Model

1. Add invited users or teams in GitHub.
2. Confirm they can read the private repo.
3. Tell them to use the private GitHub install flow from the user guide.
4. Keep maintainer-only actions out of the public user flow.

## Notes

- The README should stay user-facing.
- Admin-only instructions belong here or in a maintainer doc.
