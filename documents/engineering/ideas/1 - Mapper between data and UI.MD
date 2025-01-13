# Mapper between data and UI

_Instead of mapping data entities directly into UI we could have, for different situations, different UIs for the same data._

## Why

A doubt arose when doing the "Now" timely section. If we want to show a spinning icon inside the base card when the thing is inside this section, how we should do that?

Currently, we just have `Thing` as parameter inside base card and the base card deals internally with the UI. However, how the card should know if it's just inside the now section, it should render spinner or not?

## What

Instead of passing as prop a domain entity inside a UI widget, we can have an intermediate which will be used according to each context.

This is much better than just mapping manually each prop for each situation, because on most cases, there is just a small variation on how we want to add this.

At the same time, having a modular mapper we can test the logic inside it, and reuse it on other cases.

## How

```
class BaseCardParams{
    final String content;
    final VoidCallback onTap;
    final bool? isDone;
    final bool? isInProgress;
}

extension InProgressThingMapper on Thing {
    BaseCardParams inProgressMapToBaseCard(BuildContext context) {
        // business logic
        final isInProgress = thing.parent.tags.contains(nowSectionTag);

        // mapping to BaseCard contract
        return BaseCardParams(
            content: this.content,
            onTap: context.read<CreationBottomSheet>().edit(thing);
            isDone: this.isDone,
            isInProgress: isInProgress
        )
    }
}

// usage

...
BaseCard(
    thing.inProgressMapToBaseCard(context),
)
```
