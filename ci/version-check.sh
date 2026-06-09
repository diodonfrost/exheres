#!/usr/bin/env bash
#
# Check upstream versions with nvchecker and open an auto-merging merge request
# for every package that has a newer release. Also bumps ci/old_ver.json so the
# same update is not proposed again on the next run.
#
# Meant to run from a scheduled GitLab CI pipeline (image: python:3.13). The
# build/buildtest pipeline triggered on each pushed branch is what actually
# validates a bump before the MR is merged.
#
# Required environment (provided by GitLab CI):
#   GITLAB_TOKEN     - Project/Group Access Token (scopes: write_repository, api)
#   CI_SERVER_HOST   - e.g. gitlab.exherbo.org
#   CI_PROJECT_PATH  - e.g. diodonfrost/exheres
#   CI_DEFAULT_BRANCH - e.g. master
# Optional:
#   GITHUB_TOKEN     - raises nvchecker's GitHub API rate limit
#   DRY_RUN=1        - do everything except push (local testing)
#   SKIP_NVCHECKER=1 - reuse an existing ci/new_ver.json (local testing)
set -euo pipefail

CONFIG="ci/nvchecker.toml"
OLD_VER="ci/old_ver.json"
NEW_VER="ci/new_ver.json"
KEYFILE="ci/nvchecker-keys.toml"
TARGET_BRANCH="${CI_DEFAULT_BRANCH:-master}"
DRY_RUN="${DRY_RUN:-0}"

# --- nvchecker keyfile (token optional) ----------------------------------
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '[keys]\ngithub = "%s"\n' "${GITHUB_TOKEN}" > "${KEYFILE}"
else
    printf '[keys]\n' > "${KEYFILE}"
fi

# --- run nvchecker --------------------------------------------------------
if [[ "${SKIP_NVCHECKER:-0}" != "1" ]]; then
    command -v nvchecker >/dev/null 2>&1 || pip install --quiet nvchecker
    nvchecker -c "${CONFIG}"
fi

# --- compute the list of updates -----------------------------------------
mapfile -t UPDATES < <(python3 ci/compute_updates.py)

if [[ "${#UPDATES[@]}" -eq 0 ]]; then
    echo "All packages are up to date."
    exit 0
fi

echo "Updates detected:"
printf '  - %s\n' "${UPDATES[@]}"

# --- git / remote setup ---------------------------------------------------
git config user.name "version-check"
git config user.email "version-check@${CI_SERVER_HOST:-localhost}"
BASE_SHA="$(git rev-parse HEAD)"

REMOTE=""
if [[ "${DRY_RUN}" != "1" ]]; then
    : "${GITLAB_TOKEN:?GITLAB_TOKEN is required to push branches and open MRs}"
    REMOTE="https://oauth2:${GITLAB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git"
fi

# Push a branch and open (or update) an auto-merging MR via git push options.
push_mr() {
    local branch="$1" title="$2" desc="$3"
    if [[ "${DRY_RUN}" == "1" ]]; then
        echo "[DRY_RUN] would push '${branch}' -> MR \"${title}\""
        return 0
    fi
    git push --force "${REMOTE}" "HEAD:refs/heads/${branch}" \
        -o merge_request.create \
        -o merge_request.target="${TARGET_BRANCH}" \
        -o merge_request.title="${title}" \
        -o merge_request.description="${desc}" \
        -o merge_request.remove_source_branch \
        -o merge_request.merge_when_pipeline_succeeds
}

# --- one bump MR per package ----------------------------------------------
for line in "${UPDATES[@]}"; do
    IFS='|' read -r category name old new url <<< "${line}"
    [[ -n "${category}" ]] || continue

    old_file="packages/${category}/${name}/${name}-${old}.exheres-0"
    new_file="packages/${category}/${name}/${name}-${new}.exheres-0"
    branch="update/${name}-${new}"

    git checkout -B "${branch}" "${BASE_SHA}" >/dev/null 2>&1

    if [[ ! -f "${old_file}" ]]; then
        echo "WARNING: ${old_file} not found, skipping ${category}/${name}"
        continue
    fi

    git mv "${old_file}" "${new_file}"
    git commit --quiet -m "feat(${name}): version bump to ${new}"

    desc="Bumps \`${category}/${name}\` from \`${old}\` to \`${new}\`. Upstream release: ${url}"
    push_mr "${branch}" "Update ${name} to ${new}" "${desc}"
done

# --- bump ci/old_ver.json so updates are not re-proposed ------------------
git checkout -B chore/update-old-ver "${BASE_SHA}" >/dev/null 2>&1
python3 - "${OLD_VER}" "${NEW_VER}" <<'PY'
import json, sys

old_path, new_path = sys.argv[1], sys.argv[2]
with open(old_path) as f:
    old = json.load(f)
with open(new_path) as f:
    raw = json.load(f)
new = {k: v["version"] for k, v in raw["data"].items()} if "data" in raw else raw

old.update(new)
with open(old_path, "w") as f:
    json.dump(old, f, indent=2, sort_keys=True)
    f.write("\n")
PY

if ! git diff --quiet -- "${OLD_VER}"; then
    git add "${OLD_VER}"
    git commit --quiet -m "chore: update old_ver.json with latest upstream versions"
    push_mr "chore/update-old-ver" "chore: update old_ver.json" \
        "Auto-update known versions after nvchecker check."
fi

# Return to the starting point (relevant for local DRY_RUN runs).
git checkout --quiet "${BASE_SHA}" >/dev/null 2>&1 || true
