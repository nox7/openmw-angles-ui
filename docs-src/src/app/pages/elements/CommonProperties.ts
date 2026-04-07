import { DomSanitizer, SafeHtml } from "@angular/platform-browser";

type CSSPropertyDoc = {
  Property: string;
  DataType: string;
  Description: SafeHtml | string;
}

/**
 * Returns common CSS properties for documentation. An array of property names
 * to not include can be passed in.
 * @param ignoreProperties
 * @returns 
 */
export function GetCommonCSSProperties(
  sanitizer: DomSanitizer,
  ignoreProperties: string[] | undefined = undefined,
):  CSSPropertyDoc[] {
  
  const props: CSSPropertyDoc[] = [
    {
      Property: 'width',
      DataType: 'pixels or percentage',
      Description: 'The width of the element.'
    },
    { 
      Property: 'height', 
      DataType: 'pixels or percentage', 
      Description: 'The height of the element.' 
    },
    { 
      Property: 'position', 
      DataType: '"absolute" or "relative"', 
      Description: 'Specifies the positioning method for the element. "absolute" positions the element relative to its nearest positioned ancestor, while "relative" positions it relative to its normal position.' 
    },
    { 
      Property: 'left', 
      DataType: 'pixels or percentage', 
      Description: 'The distance the left side of the element is from the left side of its relative position parent, or the screen. Does not apply unless the element is absolutely positioned.' 
    },
    { 
      Property: 'right', 
      DataType: 'pixels or percentage', 
      Description: 'The distance the right side of the element is from the right side of its relative position parent, or the screen. Does not apply unless the element is absolutely positioned.' 
    },
    { 
      Property: 'top', 
      DataType: 'pixels or percentage', 
      Description: 'The distance the top side of the element is from the top side of its relative position parent, or the screen. Does not apply unless the element is absolutely positioned.' 
    },
    { 
      Property: 'bottom', 
      DataType: 'pixels or percentage', 
      Description: 'The distance the bottom side of the element is from the bottom side of its relative position parent, or the screen. Does not apply unless the element is absolutely positioned.' 
    },
    {
      Property: "padding",
      DataType: "pixels",
      Description: "Padding inside the element."
    },
    { 
      Property: 'flex-grow', 
      DataType: 'number', 
      Description: sanitizer.bypassSecurityTrustHtml(`Specifies how much the element will grow relative to the rest of the flexible items inside the same container. See <a target="_blank" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/flex-grow">MDN docs</a>. Only works if the parent element is a flex element.`)
    },
    { 
      Property: 'grid-column', 
      DataType: 'number or range', 
      Description: sanitizer.bypassSecurityTrustHtml(`If the parent is a grid element, this specifies the column this element takes and/or how many it spans. See <a target="_blank" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/grid-column">MDN docs</a>. We accept only the formats of "1" or "1 / span 2" as examples.`)
    },
    { 
      Property: 'grid-row', 
      DataType: 'number or range', 
      Description: sanitizer.bypassSecurityTrustHtml(`If the parent is a grid element, this specifies the row this element takes and/or how many it spans. See <a target="_blank" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/grid-row">MDN docs</a>. We accept only the formats of "1" or "1 / span 2" as examples.`)
    },
    { 
      Property: 'visibility', 
      DataType: '"hidden" or "visible"', 
      Description: 'The visibility of the element.' 
    },
    { 
      Property: 'opacity', 
      DataType: 'number', 
      Description: 'Opacity between 0 and 1.' 
    },
    { 
      Property: 'aspect-ratio', 
      DataType: 'number', 
      Description: sanitizer.bypassSecurityTrustHtml(`Forces the element to maintain the aspect ratio. This is ignored if you define <strong>both</strong> a width and height. For this to work, define only one. <strong>Note:</strong> may not function as expected, or at all, on <em>direct</em> grid or flex children.`)
    },
    { 
      Property: 'container-type', 
      DataType: '"size"', 
      Description: sanitizer.bypassSecurityTrustHtml(`Marks the element as a container for use in @container queries. See <a target="_blank" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@container">MDN docs</a>. We only support "size" as a value, which allows you to use the width and height of this element in your container queries.`)
    },
    { 
      Property: 'container-name', 
      DataType: 'string', 
      Description: sanitizer.bypassSecurityTrustHtml(`Defines the name of the container to be used in @container queries. See <a target="_blank" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@container">MDN docs</a>. If not defined, then container queries are evaluated against the nearest ancestor query container that has the matching container-type for the container query parameter property. For <code>container-type: size</code>, it is "width" or "height".`)
    },
  ];

  if (ignoreProperties !== undefined){
    return props.filter(p => !ignoreProperties.includes(p.Property));
  }

  return props;
}