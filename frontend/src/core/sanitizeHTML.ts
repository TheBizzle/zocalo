import DOMPurify from "dompurify";

function sanitizeHTML(rawHTML: string): string {
  const config =
    { ALLOWED_TAGS: [ "p", "br", "b", "i", "em", "strong", "u", "s", "a", "h1", "h2", "h3", "h4"
                    , "h5", "h6", "ul", "ol", "li","table", "thead", "tbody", "tr", "td", "th"
                    , "hr", "img", "span", "div"
                    ]
    , ALLOWED_ATTR: ["href", "src", "alt", "colspan", "rowspan", "style", "class"]
    };
  return DOMPurify.sanitize(rawHTML, config);
}

export { sanitizeHTML };
