import{a as h}from"./chunk-NZBZERZ3.js";import{a as s,b as w,c}from"./chunk-ARCBSOD7.js";import{Aa as d,Ba as i,Ca as t,Da as l,Ra as e,X as o,ea as n,hb as g,na as p}from"./chunk-Z5QWJB5W.js";import"./chunk-Q7L6LLAK.js";var f=class m{Code1=o(`
<mw-root>
  @if (ShowWindow()) {
    <mw-window></mw-window>
  }
</mw-root>
    `);Code2=o(`
<mw-root>
  @if (1 === 1) {
    <mw-window></mw-window>
  }
</mw-root>
    `);Code3=o(`
<mw-root>
  @if (ShowWindow()) {
    <mw-window></mw-window>
  } @else {
     <mw-text>No window</mw-text>
  }
</mw-root>
    `);Code4=o(`
<mw-root>
  @if (ShowWindow()) {
    <mw-window></mw-window>
  } @else if (!ShowWindow() && ShowText()) {
     <mw-text>No window, but we'll show text.</mw-text>
  } @else {
    <mw-text>No conditions passed.</mw-text>
  }
</mw-root>
    `);static \u0275fac=function(r){return new(r||m)};static \u0275cmp=p({type:m,selectors:[["app-if-directives"]],decls:22,vars:4,consts:[["Language","angular-html",3,"Code"]],template:function(r,a){r&1&&(i(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"If Directives in AnglesUI"),t()(),i(5,"app-card-body")(6,"p"),e(7," Similarly to Angular, AnglesUI supports if template syntax. This allows you to conditionally render elements in your UI. The syntax is simple, and it is used to evaluate a condition based on the current render context scope - which will be the signals that you provide to the renderer. "),t(),l(8,"app-code-highlighter",0),i(9,"p"),e(10," General data comparisons and logical operators are supported as well. "),t(),l(11,"app-code-highlighter",0),i(12,"p"),e(13," Additionally, "),i(14,"code"),e(15,"else if"),t(),e(16," and "),i(17,"code"),e(18,"else"),t(),e(19," blocks are supported. "),t(),l(20,"app-code-highlighter",0)(21,"app-code-highlighter",0),t()()()),r&2&&(n(8),d("Code",a.Code1()),n(3),d("Code",a.Code2()),n(9),d("Code",a.Code4()),n(),d("Code",a.Code3()))},dependencies:[g,s,w,c,h],encapsulation:2})};export{f as IfDirectives};
