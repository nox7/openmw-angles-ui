import{a as x}from"./chunk-MT6I4FAW.js";import{a as p,b as g,c as h}from"./chunk-HUSNLUSQ.js";import{b as w}from"./chunk-3IW3OY67.js";import"./chunk-4NUQGYMS.js";import{Ka as s,Ua as r,Va as i,Wa as t,Xa as l,Z as o,jb as e,wa as a,wb as u}from"./chunk-5ROAAEKF.js";import"./chunk-Q7L6LLAK.js";var c=class d{Code1=o(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-text>Hello world!</mw-text>
  </mw-window>
</mw-root>
  `.trim());Code2=o(`
<mw-root
  Layer="Windows"
  [style.width]="InitialWidth()"
  [style.height]="InitialHeight()"
  >
  <mw-window>
    <mw-text>{{ Text() }}</mw-text>
  </mw-window>
</mw-root>
  `.trim());Code3=o(`
<mw-root
  Layer="Windows"
  [style.width]="InitialWidth()"
  [style.height]="InitialHeight()"
  >
  @if (ShowManageKingdomWindow()){
    <mw-window>
      <mw-text>Manage Your Kingdom's Staff Schedules</mw-text>
    </mw-window>
  }

  @if (ShowOverviewWindow()){
    <mw-window>
      <mw-text>Overview of Your Castle</mw-text>
    </mw-window>
  }
</mw-root>
  `.trim());static \u0275fac=function(n){return new(n||d)};static \u0275cmp=s({type:d,selectors:[["app-html-syntax"]],decls:70,vars:3,consts:[["Language","angular-html",3,"Code"],["routerLink","data-binding"],["href","examples/making-a-button"]],template:function(n,m){n&1&&(i(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"HTML Templating Syntax"),t()(),i(5,"app-card-body")(6,"p"),e(7," Instead of just plain HTML, AnglesUI is extended to use a custom templating syntax. However, at the baseline it is just plain HTML. "),t(),l(8,"app-code-highlighter",0),i(9,"p"),e(10," An example of using the extended syntax may look something like the below: "),t(),l(11,"app-code-highlighter",0),i(12,"p"),e(13," This form is called data binding - where you input signals of data for the UI to react to. You can read more about how to register signals and how data binding works "),i(14,"a",1),e(15,"on this page"),t(),e(16,". "),t(),i(17,"p"),e(18," You can also use if statements to conditionally render elements. "),t(),l(19,"app-code-highlighter",0),i(20,"h2"),e(21,"All Valid HTML Elements"),t(),i(22,"p"),e(23," This is a list of all of the HTML elements that AnglesUI supports and what they do and any valid attributes on them. "),t(),i(24,"ul")(25,"li")(26,"strong"),e(27,"mw-root"),t(),e(28,": The root element of an AnglesUI rendered parent."),t(),i(29,"li")(30,"strong"),e(31,"mw-window"),t(),e(32,": A pre-styled Morrowind-UI window. Automatically has height 100% and width 100% of its parent."),t(),i(33,"li")(34,"strong"),e(35,"mw-text"),t(),e(36,": A text element pre-styled to use Morrowind-style text. Has OpenMW UI autoSize set to true by default."),t(),i(37,"li")(38,"strong"),e(39,"mw-widget"),t(),e(40,": A generic widget element with no styling. Think of it as a base container for styling or elements. In the HTML world, this would be your <div>"),t(),i(41,"li")(42,"strong"),e(43,"mw-flex"),t(),e(44,": A custom flexbox implementation. Used for putting your elements in rows or columns, but not usually both."),t(),i(45,"li")(46,"strong"),e(47,"mw-grid"),t(),e(48,": A custom grid implementation. Used for creating more complex grid-like layouts with multiple cells in rows and column format."),t(),i(49,"li")(50,"strong"),e(51,"mw-image"),t(),e(52,": Renders an image resource."),t(),i(53,"li")(54,"strong"),e(55,"mw-text-edit"),t(),e(56,": A text input field for the user to type into. Listen for the textInput or textChanged events to react to user input."),t(),i(57,"li")(58,"strong"),e(59,"mw-hr"),t(),e(60,": A horizontal line styled in Morrowind-UI theme."),t(),i(61,"li")(62,"strong"),e(63,"mw-scroll-canvas"),t(),e(64,": An element that provides a scrollable canvas area for arbitrary content. Works for both vertical and horizontal scrolling. Styled in Morrowind-UI theme."),t()(),i(65,"p"),e(66,` You may be wondering why you don't see something like a button, for example. The reason is because AnglesUI is a framework for you to make your own components - with some pre-configured for a "batteries partially included" effect. Read `),i(67,"a",2),e(68,"making a button"),t(),e(69," for a guide on how to make your own Morrowind-themed clickable button. "),t()()()()),n&2&&(a(8),r("Code",m.Code1()),a(3),r("Code",m.Code2()),a(8),r("Code",m.Code3()))},dependencies:[u,p,g,h,x,w],encapsulation:2})};export{c as HtmlSyntax};
