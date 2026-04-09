import{a as f}from"./chunk-FCHIL3KZ.js";import{a as y}from"./chunk-4UVQU5FT.js";import{a as h,b as g,c as b}from"./chunk-OI63Y6K5.js";import{f as w}from"./chunk-73NXMPKY.js";import"./chunk-X23CRHME.js";import{Aa as l,Lb as x,Pa as d,ab as u,ba as i,bb as e,cb as n,db as p,sb as t,xb as m,yb as s}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var C=o=>({TabLabel:"Parent.html",Code:o,Language:"angular-html"}),S=o=>({TabLabel:"Button.html",Code:o,Language:"angular-html"}),E=(o,c)=>[o,c],j=class o{ParentComponent=i(`
<mw-root Layer="Windows">
  <my-custom-button>Button text 1</my-custom-button>
  <my-custom-button>Button text 2</my-custom-button>
  <my-custom-button>Button text 3</my-custom-button>
</mw-root>
  `);ButtonComponent=i(`
<mw-widget class="button">
  <mw-text><mw-content></mw-content></mw-text>
</mw-widget>
  `);ParentComponent2=i(`
<mw-root Layer="Windows">
  <my-custom-button>
    <mw-image Resource="icons/a/a_shield_breaker.dds"></mw-image>  
    Button text 1
  </my-custom-button>
</mw-root>
  `);ButtonComponent2=i(`
<mw-widget class="button">
  <mw-flex>
    <mw-content select="mw-image"></mw-content>
    <mw-text><mw-content></mw-content></mw-text>
  </mw-flex>
</mw-widget>
  `);static \u0275fac=function(a){return new(a||o)};static \u0275cmp=d({type:o,selectors:[["app-content-projection"]],decls:44,vars:16,consts:[["routerLink","/examples/custom-components"],[3,"CodeTabs"]],template:function(a,r){a&1&&(e(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),t(4,"Content Projection"),n()(),e(5,"app-card-body")(6,"p"),t(7," When you utilize "),e(8,"a",0),t(9,"custom components"),n(),t(10,", you will often find yourself needing to pass content into your recycled component. This is where content projection comes in. Content projection allows you to pass content from a parent component to a child component. Specifically, your child component will utilize "),e(11,"code"),t(12,"<mw-content>"),n(),t(13," elements to indicate where your project content should go. "),n(),e(14,"h2"),t(15,"Basic Usage"),n(),e(16,"p"),t(17," Let's say we have a basic parent component and child component - a button. We want to pass the text of the button in from the parent's HTML (naturally, so we can make use of our button multiple times with different text). "),n(),p(18,"app-code-highlighter",1),e(19,"app-alert"),t(20," Using "),e(21,"code"),t(22,"<mw-content>"),n(),t(23," without a "),e(24,"code"),t(25,"select"),n(),t(26," attribute will project all content into that element. "),n(),e(27,"h2"),t(28,"Using the Select Attribute on "),e(29,"code"),t(30,"<mw-content>"),n()(),e(31,"p"),t(32," If you have multiple "),e(33,"code"),t(34,"<mw-content>"),n(),t(35," elements in your child component, you can use the "),e(36,"code"),t(37,"select"),n(),t(38," attribute to specify which content goes where. The value of the select attribute is a CSS selector. "),n(),e(39,"p"),t(40," Let's expand our button example by projecting not only text, but an image element to serve as our icon. We'll use the select attribute with a basic tag name CSS selector (so no special characters in our selector other than the tag name to project). "),n(),p(41,"app-code-highlighter",1),e(42,"p"),t(43," Now, our button can accept more outside content and we can control where it gets placed (projected) in our custom button component. "),n()()()()),a&2&&(l(18),u("CodeTabs",s(6,E,m(2,C,r.ParentComponent()),m(4,S,r.ButtonComponent()))),l(23),u("CodeTabs",s(13,E,m(9,C,r.ParentComponent2()),m(11,S,r.ButtonComponent2()))))},dependencies:[x,h,g,b,w,y,f],encapsulation:2})};export{j as ContentProjection};
