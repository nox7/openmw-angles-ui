import{a as S}from"./chunk-RKRXWAUF.js";import{a as C}from"./chunk-GN3ABOUD.js";import{a as g}from"./chunk-EGUWTU4E.js";import{a as m,b as u,c}from"./chunk-XFPJAEYH.js";import"./chunk-XST6YTRK.js";import{$ as r,$a as t,Db as h,Ma as p,Za as o,_a as i,ab as n,ob as e,ya as a}from"./chunk-V3XGVJ3S.js";import"./chunk-Q7L6LLAK.js";var f=class d{GeneralAndCompoundCode=r(`
.red-text {
  color: rgb(255, 0, 0);
}

.red-text.hidden {
  visibility: hidden;
}
  `);NestedRuleCode=r(`
mw-window {
  mw-text {
    color: rgb(255, 0, 0);
  }
}
  `);NotSelectorCode=r(`
.grid-1:not(.active) {
  visibility: hidden;
}
  `);MediaQueriesCode=r(`
@media (max-width: 600px) {
  /* Rules applied when the screen width is less than or equal to 600px */
  .grid-1 {
    grid-template-columns: 1fr;
  }
}
  `);ContainerQueriesCode=r(`
.grid-container {
  container-type: size;
  container-name: grid-container;

  .grid-1 {
    grid-template-columns: 1fr 1fr;
  }
}
  
@container grid-container (width <= 600px) {
  /* Rules applied when the container width is less than or equal to 600px */
  /* This collapses the grid into a single column when it's container is too small. */
  .grid-1 {
    grid-template-columns: 1fr;
  }
}
  `);static \u0275fac=function(s){return new(s||d)};static \u0275cmp=p({type:d,selectors:[["app-css"]],decls:57,vars:5,consts:[["Alt","Same base name file structure","Src","/images/css/file-structure.png"],["Language","css",3,"Code"],["target","_blank","href","https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Containment/Container_queries"]],template:function(s,l){s&1&&(i(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"The AnglesUI Framework"),t()(),i(5,"app-card-body")(6,"p"),e(7," In AnglesUI, you write styling for your elements in dedicated CSS files. These files must have the same base name as your HTML file, but with a .css extension. "),t(),n(8,"app-content-image",0),i(9,"p"),e(10," The renderer will automatically find this file when you load your HTML into the renderer and parse, evaluate, and apply the CSS rules. "),t(),i(11,"h2"),e(12,"What CSS is Supported?"),t(),i(13,"p"),e(14," Not all of CSS properties and features are supported, naturally. This page serves as an "),i(15,"em"),e(16,"exhaustive list"),t(),e(17," of what is supported. In general, try to write simple CSS. "),t(),i(18,"app-alert"),e(19," Not all properties are supported on all elements. View that element's individual documentation for what properties it supports. "),t(),i(20,"h3"),e(21,"General Rules and Compound Selectors"),t(),i(22,"p"),e(23," All single rules are supported as well as compound selectors. "),t(),n(24,"app-code-highlighter",1),i(25,"h3"),e(26,"Rule Nesting"),t(),i(27,"p"),e(28," Nested rules (a relatively new baseline CSS feature) is supported. "),t(),n(29,"app-code-highlighter",1),i(30,"h3"),e(31,"Pseudo-States"),t(),i(32,"p"),e(33," We "),i(34,"strong"),e(35,"do not"),t(),e(36," support psuedo states such as :hover, :active, :focus, etc. "),t(),i(37,"h3"),e(38,":not() Selector"),t(),i(39,"p"),e(40," This selector is supported. "),t(),n(41,"app-code-highlighter",1),i(42,"h3"),e(43,"Media Queries"),t(),i(44,"p"),e(45," We support media queries in the following format: "),t(),n(46,"app-code-highlighter",1),i(47,"h3"),e(48,"Container Queries"),t(),i(49,"p"),e(50," In general, we highly recommend using containers instead of media queries. They are cheaper to process but also more relevant - as they apply specifically to the containing element's side instead of the entire viewport. "),t(),i(51,"p"),e(52,' Container queries are also "relatively new" in the CSS world, and can be confusing at first. Read the '),i(53,"a",2),e(54,"MDN documentation"),t(),e(55," on them. "),t(),n(56,"app-code-highlighter",1),t()()()),s&2&&(a(24),o("Code",l.GeneralAndCompoundCode()),a(5),o("Code",l.NestedRuleCode()),a(12),o("Code",l.NotSelectorCode()),a(5),o("Code",l.MediaQueriesCode()),a(10),o("Code",l.ContainerQueriesCode()))},dependencies:[h,m,u,c,g,S,C],encapsulation:2})};export{f as Css};
