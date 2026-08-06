# Branch protection setup (owner only)

This is the **one-time** configuration @saurabhprasad20 applies on GitHub to
enforce the contribution rules. It cannot be committed as code — it lives in the
repository's GitHub settings. Two equivalent ways are given: the **web UI**
(recommended, no token needed) and an **API script** (one paste).

## What we're enforcing
On the `master` branch of `saurabhprasad20/TravAcs`:

| Requirement | Setting |
|---|---|
| Only the owner can push to `master` directly | Require a PR before merging + do **not** include administrators (owner, as admin, keeps direct push; all Write collaborators are blocked and must open PRs) |
| Owner is a required approver | `.github/CODEOWNERS` (`* @saurabhprasad20`) + **Require review from Code Owners** |
| ≥1 reviewer other than the author | **Require approvals = 1** (GitHub never counts the author's own review) |
| Owner's approval always required | Same as the code-owner rule above |
| No history rewrite / deletion of `master` | Block force pushes + block deletions |
| Re-review after new commits | Dismiss stale approvals + require approval of the last push |

> **Important — collaborator role:** invite contributors with the **Write** role
> only (Settings → Collaborators). If someone is given **Admin**, branch
> protection won't stop them (admins bypass, since we intentionally leave
> administrators un-enforced so the *owner* can still push directly).

---

## Option A — GitHub web UI (recommended)

### 1. Add the code owner (already in the repo)
`.github/CODEOWNERS` already contains `* @saurabhprasad20`. Nothing to do beyond
merging it to `master`.

### 2. Create the branch protection rule
1. Go to **Settings → Branches** →
   https://github.com/saurabhprasad20/TravAcs/settings/branches
2. Under **Branch protection rules**, click **Add branch ruleset** *or* the
   classic **Add rule**. (Steps below are for the classic **Add rule**, which
   maps 1:1 to the requirements.)
3. **Branch name pattern:** `master`
4. Enable **Require a pull request before merging**, then:
   - **Require approvals** → set to **1**.
   - Check **Dismiss stale pull request approvals when new commits are pushed**.
   - Check **Require review from Code Owners**.
   - Check **Require approval of the most recent reviewable push**.
5. (Recommended) Enable **Require status checks to pass before merging** and
   select the CI checks once they've run at least once on a PR:
   **`flutter-tests`** and **`backend-tests`** (from `.github/workflows/ci.yml`).
   Also check **Require branches to be up to date before merging**.
6. (Recommended) Enable **Require conversation resolution before merging**.
7. Under **Rules applied to everyone including administrators**, **leave
   "Do not allow bypassing the above settings" / "Include administrators"
   UNCHECKED** — this is what keeps *your* direct-push ability while blocking
   everyone else.
8. Enable **Do not allow force pushes** and **Do not allow deletions** (these are
   usually on by default for a protected branch; confirm they're set).
9. Click **Create** / **Save changes**.

That's it — contributors can now only land changes on `master` through an
approved pull request.

---

## Option B — API script (one paste)

Run this in **PowerShell**. It applies the exact same classic branch-protection
settings via the REST API. You need a **Personal Access Token** with the
**`repo`** scope (classic PAT) or a fine-grained token with
**Administration: Read and write** on this repo.

Create a token: https://github.com/settings/tokens (classic → check `repo`).

```powershell
# 1) Paste your admin token (it is only sent to api.github.com over HTTPS):
$token = Read-Host -AsSecureString "GitHub admin token"
$tok   = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
           [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))

$owner  = 'saurabhprasad20'
$repo   = 'TravAcs'
$branch = 'master'
$headers = @{
  Authorization = "Bearer $tok"
  Accept        = 'application/vnd.github+json'
  'User-Agent'  = 'travacs-branch-protection'
  'X-GitHub-Api-Version' = '2022-11-28'
}

# 2) The protection payload (mirrors Option A).
#    required_status_checks is null here; switch to the commented block once the
#    CI checks have appeared on a PR and you want them enforced.
$body = @{
  required_status_checks = $null
  # required_status_checks = @{ strict = $true; contexts = @('flutter-tests','backend-tests') }
  enforce_admins = $false          # keep owner's direct push; block everyone else
  required_pull_request_reviews = @{
    dismiss_stale_reviews           = $true
    require_code_owner_reviews      = $true    # -> @saurabhprasad20 required
    required_approving_review_count = 1        # -> >=1 non-author approval
    require_last_push_approval      = $true
  }
  restrictions                     = $null     # (push restrictions are org-only)
  required_linear_history          = $false
  allow_force_pushes               = $false
  allow_deletions                  = $false
  block_creations                  = $false
  required_conversation_resolution = $true
} | ConvertTo-Json -Depth 6

# 3) Apply it.
$uri = "https://api.github.com/repos/$owner/$repo/branches/$branch/protection"
Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body -ContentType 'application/json' |
  ConvertTo-Json -Depth 6

# 4) (optional) Verify:
Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 6

# 5) Clear the token from memory.
Remove-Variable tok, token, headers -ErrorAction SilentlyContinue
```

> **Do not paste the token into any file or commit it.** The script reads it
> interactively and only sends it to `api.github.com`.

---

## Verifying it works
- As a **non-owner Write collaborator**, `git push origin master` should be
  **rejected** ("protected branch"). Pushing a feature branch works, and a PR
  into `master` shows *"Review required"* + *"Code owner review required"*.
- Merging is disabled until **@saurabhprasad20 approves**, there's **≥1
  non-author approval**, and (if enabled) the **CI checks pass**.
- As the **owner**, you can still push to `master` directly (admins are not
  enforced by design).

## Changing the rules later
Re-run Option A/B with new values, or edit the rule at
**Settings → Branches**. To require a *second* human reviewer in addition to the
owner, bump **Require approvals** to `2`.
