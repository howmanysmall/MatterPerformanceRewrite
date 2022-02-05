# Matter2
faster for what matters

[Original](https://github.com/evaera/matter)

I only rewrote this to learn the API better and to see if I was able to make it faster. I think I succeeded in doing both, so here it is.

## Changes

- PascalCase for the API (still supports camelCase)
- Queue uses an array instead of a linked list (way faster)
- Type exports for easier use
- Removed Llama dependency
- `World:size()` is now a property, which makes more sense to me. Just don't edit it externally.
- `"default"` for loops is now `"Default"`, which makes sense since you can use it as a property.
	- **Before:** `loop:begin({default = BindableEvent.Event}).default:Disconnect()`
	- **After:** `loop:Begin({Default = BindableEvent.Event}).Default:Disconnect()`
- Performance focused changes, a lot of which are micro optimizations.
