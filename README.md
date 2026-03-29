# Angles UI Template Language for OpenMW
OpenMW's code-first approach to UI is technically efficient and gives the user a lot of freedom of control. However, mod makers need results and we need a faster way to create and manage UIs that are reactive to stateful changes. Angles UI was created with inspiration from Angular and how it is a signal-first approach to UI changes with an HTML-friendly template language.

## Example
`mw-box` is the Angles UI way to create a bordered container with a black background that respects the users' alpha settings without you having to do any customization to the element. You can use attribute bindings with "[]" brackets to evaluate code as property values. Use non-bound attribute values for plain-data bindings.
```html
<mw-box [width]="X()" [height]="Y()">
  @if (ShowGuardManager()) {
    <mw-flex relativeWidth="1" relativeHeight="1">
      <mw-text TextSize="24">Manage your castle guards here.</mw-text>
    </mw-flex>
  }

  @if (ShowStaffManager()) {
    <mw-flex relativeWidth="1" relativeHeight="1">
      <mw-text TextSize="24">Manage your general castle staff here.</mw-text>
    </mw-flex>
  }
</mw-box>
```

You can see two different components inside the if-directives. They will only render these components if those signal functions return true.

## Child Components
Because a single HTML template file can become massive and complicated, you can register your own custom component tags in the template compiler file so that you can separate your HTML code and conditional logic in separate files.

**Note**: For those of you familiar with Angular, this is where we diverge a bit in how logical contexts work. Usually, when you have separate components they have separate variable contexts. In our case, your variable context is dependent on where you rendered the UI and all sub-components will inherit that context.

*MainManager.html*
```html
<mw-box [width]="X()" [height]="Y()">
  @if (ShowGuardManager()) {
    <nox-guard-manager></nox-guard-manager>
  }

  @if (ShowStaffManager()) {
    <nox-castle-manager></nox-castle-manager>
  }
</mw-box>
```

*GuardManager.html*
```html
<mw-flex relativeWidth="1" relativeHeight="1">
  <mw-text TextSize="24">Manage your castle guards here.</mw-text>
</mw-flex>
```

*StaffManager.html*
```html
<mw-flex relativeWidth="1" relativeHeight="1">
  <mw-text TextSize="24">Manage your general castle staff here.</mw-text>
</mw-flex>
```

## Unit Tests
Currently, unit tests are ignored from the repository. For what it's worth, I do have them but wrote them without a standardized library. I'll incorporate a standardized Lua tests library and publish the tests.