# Swipe right to move to done

_Instead of having a check box to toggle the thing to done/undone, have the gesture to swipe right and swipe left to toggle it as done/undone._

## Why:

We occupy a big space on the left to something that is used only once. Maybe another gesture is a good way to interact with the card without the need to add any other element.

## What:

- When user swipes a little to the right, it shows a little icon on the left revelaing it can swipe even further to mark it as done.
- When user finishes the swipe, it moves to done.

## How:

- Find some library that does that
- Change the content of base card

## Notes:

- We can understand if this is the most intutive way to do that. Another option is when user is preparing to drag the thing it shows a couple of buttons underneath (delete/done for example), so when the user releases it on one of those, perform the action.
