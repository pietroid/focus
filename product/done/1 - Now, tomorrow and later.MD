# Now, tomorrow and later home screen

_Show three draggable lists: now, tomorrow and later._

## Why:

Most common sort of prioritization is timely, so we want to provide a simple interface where the user always can drag one thing from one of three lists and they will remember which things to do in order.

## What:

We will provide three fixed lists:

- Today
- Tomorrow
- Later

They will be draggable lists (we can move things from one list to another).

## How:

We need to create:

- A draggable list component (ui)
- A generic draggable list with query and drag-in/drag-out actions (core)
- The home screen itself

For now, we don't move the things automatically from one list to another.

## Extra:

We aim to use the new architecture defined for our product.
