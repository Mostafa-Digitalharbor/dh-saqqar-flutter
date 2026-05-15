<!--
Thanks for the PR! A few notes before you open it:

1. Run `flutter analyze` and `flutter test` locally; CI will run them too
   but failing fast on your machine is cheaper.
2. Test on both Light and Dark themes, and in both English (LTR) and
   Arabic (RTL) before requesting review. The brand looks right in all
   four combinations.
3. New user-facing strings must go through `AppStrings` (EN + AR). Don't
   hard-code English in widgets.
4. Avoid amber / yellow ambient glows on dark backgrounds — they read as
   "tar-coloured" against the navy bg. See chat_screen polish history.
-->

## Summary

<!-- 1-3 short bullets describing what changed and why. Focus on the "why".
     Example:
     - Wire conversations list to the live API so the demo stops shipping
       cached demo data.
     - Replace the static empty state with the welcoming ConversationsEmptyState.
-->

-

## Screenshots

<!-- Drop side-by-side screenshots for any visible change. -->
<!-- | Dark | Light | Arabic (RTL) | -->
<!-- | ---- | ----- | ------------ | -->
<!-- |      |       |              | -->

## Test plan

- [ ] `flutter analyze` is clean
- [ ] `flutter test` is green
- [ ] Manually verified in **Light** theme
- [ ] Manually verified in **Dark** theme
- [ ] Manually verified in **English** (LTR)
- [ ] Manually verified in **Arabic** (RTL)
- [ ] No new hard-coded strings (everything goes through `AppStrings`)
- [ ] Touch targets ≥ 44×44 pt
- [ ] If a widget animates: still works correctly under OS Reduce Motion

## Related

<!-- Link the spec section, GitHub issue, Linear ticket, or PR this builds on. -->
