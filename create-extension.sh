#!/usr/bin/env bash

REPO_NAME=""
REPO_USER="mcanouil"
REPO_TEMPLATE="mcanouil/quarto-extension"
OPEN=false

# bash ./create-extension.sh --repository quarto-{{EXTENSION}} --what filter --path ~/Projects/quarto

usage() {
  echo "Usage: $0 --repository <repo_name> --what <extension_type> [--template <repo_template>] [--path <path>] [--open] [--help]"
  echo "  -r, --repository  Repository name (required)"
  echo "  -w, --what        Quarto extension type (shortcode, filter, theme) (required)"
  echo "  -p, --path        Repository path"
  echo "  -o, --open        Open repository in Visual Studio Code"
  echo "  -t, --template    Repository template (default: mcanouil/quarto-extension)"
  echo "  -h, --help        Display this help message"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -r|--repository) REPO_NAME="$2"; shift ;;
    -p|--path) REPO_PATH="$2"; shift ;;
    -w|--what) EXTENSION_TYPE="$2"; shift ;;
    -o|--open) OPEN=true ;;
    -t|--template) REPO_TEMPLATE="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
  esac
  shift
done

if [ -z "${REPO_NAME}" ]; then
  echo "Error: Repository name is required."
  usage
  exit 1
fi

if [ -z "${EXTENSION_TYPE}" ]; then
  echo "Error: Quarto extension type is required."
  usage
  exit 1
fi

gh repo create "${REPO_USER}/${REPO_NAME}" --template "${REPO_TEMPLATE}" --private --disable-wiki
sleep 2
labels=$(gh label list --repo "${REPO_USER}/${REPO_NAME}" --json name -q '.[].name')
while IFS= read -r label; do
  gh label delete "${label}" --repo "${REPO_USER}/${REPO_NAME}" --yes
done <<< "${labels}"

gh label clone "${REPO_TEMPLATE}" --repo "${REPO_USER}/${REPO_NAME}"
gh repo edit "${REPO_USER}/${REPO_NAME}" --allow-update-branch --delete-branch-on-merge --enable-auto-merge --enable-projects=false

rulesets=$(
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/${REPO_TEMPLATE}/rulesets" --jq '.[] | ._links.self.href | sub("https://api.github.com"; "")'
)

while IFS= read -r ruleset; do
  ruleset_json=$(
    gh api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${ruleset}"
  )
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/${REPO_USER}/${REPO_NAME}/rulesets" \
    --method POST \
    --input <(echo "${ruleset_json}") > /dev/null 2>&1
done <<< "${rulesets}"

if [ -n "${REPO_PATH}" ]; then
  gh repo clone "${REPO_USER}/${REPO_NAME}" "${REPO_PATH}/${REPO_NAME}"
else
  gh repo clone "${REPO_USER}/${REPO_NAME}"
fi

(
  if [ -n "${REPO_PATH}" ]; then
    cd "${REPO_PATH}/${REPO_NAME}" || exit
  else
    cd ${REPO_NAME} || exit
  fi

  EXTENSION=${REPO_NAME#quarto-}
  git rm create-extension.sh
  rm -f README.md
  git mv README-template.md README.md
  sed -i '' "s/{{EXTENSION}}/${EXTENSION}/g" README.md
  sed -i '' "s/{{EXTENSION}}/${EXTENSION}/g" example.qmd
  sed -i '' "s/{{EXTENSION}}/${EXTENSION}/g" CITATION.cff
  sed -i '' "s/{{EXTENSION}}/${EXTENSION}/g" .github/ISSUE_TEMPLATE/config.yml
  git add README.md example.qmd CITATION.cff .github/ISSUE_TEMPLATE/config.yml

  quarto create extension ${EXTENSION_TYPE} ${EXTENSION} --no-open
  if [ -d ${EXTENSION}/_extensions ]; then
    mv ${EXTENSION}/_extensions ./
  fi
  if [ -f ${EXTENSION}/example.qmd ]; then
    mv ${EXTENSION}/example.qmd ./example-${EXTENSION_TYPE}.qmd
  fi
  rm -rf ${EXTENSION}
  cp LICENSE _extensions/${EXTENSION}/LICENSE
  sed -i '' "s/version: 1.0.0/version: 0.0.0/g" _extensions/${EXTENSION}/_extension.yml
  git add _extensions/${EXTENSION}
  git commit -m "chore: cleanup template files and set extension name to ${EXTENSION}"
  git push origin main
)

if [ "${OPEN}" = true ]; then
  if [ -n "${REPO_PATH}" ]; then
    code ${REPO_PATH}/${REPO_NAME}
  else
    code ${REPO_NAME}
  fi
fi
