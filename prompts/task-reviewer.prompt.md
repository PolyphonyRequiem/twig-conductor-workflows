Review the implementation of task #{{ task_manager.output.current_task_id }} — {{ task_manager.output.current_task_title }}.
**Task description:** {{ task_manager.output.current_task_description }}
**Coder's changes:** {{ coder.output.changes_summary }}
**Files:** {{ coder.output.files_modified | join(", ") }}
**Tests:** {{ coder.output.tests_added | join(", ") }}
{% if coder.output.edge_cases_handled | length > 0 %}
**Edge cases handled:** {{ coder.output.edge_cases_handled | join(", ") }}
{% endif %}

{% if task_reviewer is defined and task_reviewer.output %}
**Review attempt:** {{ (task_reviewer.output.review_attempt | default(0)) + 1 }}
{% endif %}

## Review Cap

If this is review attempt 3 or higher, you MUST either APPROVE (if the code is
functional even if imperfect) or escalate to the user via a clear note in your
feedback. Do NOT reject indefinitely — 2 rejections is the cap before the coder
has had enough guidance to succeed or fail definitively.

## Review Tasks

1. **Requirements Verification**
   - Verify that all requirements from the task description are met
   - Check that acceptance criteria are satisfied
   - Ensure no requirements were missed

2. **Code Quality**
   - Clean, idiomatic C#? Follows project conventions (sealed classes, primary constructors)?
   - No reflection, JSON uses TwigJsonContext? AOT-compatible?
   - Proper error handling at system boundaries?

3. **Edge Case Verification**
   - Confirm edge cases were handled appropriately
   - Check error handling is comprehensive
   - Verify no stale references — renamed/removed methods updated at ALL call sites

4. **Test Coverage**
   - Verify tests cover the new functionality
   - Check that tests cover edge cases and error conditions
   - Run `dotnet test --settings test.runsettings` to verify all tests pass

Provide APPROVE or REQUEST_CHANGES with specific feedback.
Also note what was done well — strengths help reinforce good patterns.
