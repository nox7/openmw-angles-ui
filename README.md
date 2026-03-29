# Angles UI Template Language for OpenMW
OpenMW's code-first approach to UI is technically efficient and gives the user a lot of freedom of control. However, mod makers need results and we need a faster way to create and manage UIs that are reactive to stateful changes. Angles UI was created with inspiration from Angular and how it is a signal-first approach to UI changes with an HTML-friendly template language.

## Example

`mw-root` is required for all parent components (your base component). Think of it like the invisible container element for all of your visuals to go into. You would set your widths and heights here too.

`mw-window` is the Angles UI way to create a bordered container with a black background that respects the users' alpha settings without you having to do any customization to the element. You can use attribute bindings with "[]" brackets to evaluate code as property values. Use non-bound attribute values for plain-data bindings.

```html
<mw-root Layer="Windows" [Width]="WidthInPixels()" [Height]="HeightInPixels()">
  <mw-window>
    @if (ShowGuardManager()) {
      <mw-flex RelativeWidth="1" RelativeWidth="1" Padding="10">
        <mw-text>Manage your castle guards here.</mw-text>
      </mw-flex>
    }

    @if (ShowStaffManager()) {
      <mw-flex RelativeWidth="1" RelativeWidth="1" Padding="10">
        <mw-text>Manage your general castle staff here. You have {{ NumberOfStaff() }} castle staff!</mw-text>
      </mw-flex>
    }
  </mw-window>
</mw-root>
```

You can see two different components inside the if-directives. They will only render these components if those signal functions return true.

You would store this file somewhere in your mod's directories so that it can be accessed by OpenMW's `vfs` module. Here is an example of the Lua code to render your file - you would call this when you want the UI to show up to the user.

```lua
local renderer = Renderer.FromFile("scripts/Nox/UI/CastleManager.html", {})
local context = {
  WidthInPixels = Signal.New(800),
  HeightInPixels = Signal.New(400)
  NumberOfStaff = Signal.New(10)
}

renderer:Render(context)
```

Later on in your Lua code, you can modify those signals, and your UI will *automatically re-render to show the updated values*.

```lua
context.NumberOfSet:Set(13)
```

That's it.

## Child Components
Because a single HTML template file can become massive and complicated, you can register your own custom component tags in the template compiler file so that you can separate your HTML code and conditional logic in separate files.

**Note**: For those of you familiar with Angular, this is where we diverge a bit in how logical contexts work. Usually, when you have separate components they have separate variable contexts. In our case, your variable context is dependent on where you rendered the UI and all sub-components will inherit that context.

*MainManager.html*
```html
<mw-root Layer="Windows" [Width]="WidthInPixels()" [Height]="HeightInPixels()">
  <mw-window>
    @if (ShowGuardManager()) {
      <nox-guard-manager></nox-guard-manager>
    }

    @if (ShowStaffManager()) {
      <nox-staff-manager></nox-staff-manager>
    }
  </mw-window>
</mw-root>
```

*GuardManager.html*
```html
<mw-flex RelativeWidth="1" RelativeWidth="1" Padding="10">
  <mw-text>Manage your castle guards here.</mw-text>
</mw-flex>
```

*StaffManager.html*
```html
<mw-flex RelativeWidth="1" RelativeWidth="1" Padding="10">
  <mw-text>Manage your general castle staff here. You have {{ NumberOfStaff() }} castle staff!</mw-text>
</mw-flex>
```

In order for the renderer to understand what your custom tags mean (custom tags being the HTML elements that don't start with `mw-`) you must register them and their source code when you call `Renderer.FromFile`

```lua
local renderer = Renderer.FromFile("scripts/Nox/UI/CastleManager.html", {
  ["nox-guard-manager"] = "scripts/Nox/UI/GuardManager.html",
  ["nox-staff-manager"] = "scripts/Nox/UI/StaffManager.html",
})
```

## Unit Tests
Currently, unit tests are ignored from the repository. For what it's worth, I do have them but wrote them without a standardized library. I'll incorporate a standardized Lua tests library and publish the tests.
