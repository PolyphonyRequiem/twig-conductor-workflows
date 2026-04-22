Fix the issues identified in the PR review.
**PR:** {{ pr_submit.output.pr_url }}
**Feedback:** {{ pr_reviewer.output.feedback | default('') }}
**Issues:**
{% for issue in pr_reviewer.output.issues %}
- {{ issue }}
{% endfor %}
## Steps
1. Address each issue specifically
2. Run targeted tests: `dotnet test tests/<RelevantProject>.Tests --no-build --settings test.runsettings`
3. Commit: `git add -A && git commit -m "fix: address PR review feedback"`
4. Push: `git push`
