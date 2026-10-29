// 16:9 slide template for the triple-barrier deck. Shares colours and fonts with
// the intro report (../intro/theme.typ). Compile the deck from this folder:
//   typst compile --root .. main.typ

#import "../intro/theme.typ": *

#let deck-title = "Triple barriers & meta-labeling"
#let mono = ("Menlo", "DejaVu Sans Mono")
#let blue = rgb("#285c8e")
#let blue-soft = rgb("#edf3f9")

#let setup(body) = {
  set document(title: deck-title, author: "Elie Bruno")
  set page(
    paper: "presentation-16-9",
    margin: (x: 1.45cm, top: 1.15cm, bottom: 1.05cm),
    footer: context {
      set text(size: 8.5pt, fill: muted)
      grid(
        columns: (1fr, auto),
        [#deck-title · Elie Bruno · NII],
        [#counter(page).display() / #counter(page).final().first()],
      )
    },
  )
  set text(font: sans, size: 18pt, fill: ink, lang: "en")
  set par(leading: 0.6em, spacing: 0.85em, justify: false)
  set list(marker: text(fill: accent, sym.bullet), indent: 0.1em, body-indent: 0.45em, spacing: 0.7em)
  set enum(indent: 0.1em, body-indent: 0.45em, spacing: 0.7em,
    numbering: n => text(fill: accent, weight: "semibold", str(n) + "."))
  show strong: set text(weight: "semibold")
  show link: set text(fill: accent)
  show raw: set text(font: mono, size: 0.82em)
  show math.equation: set text(font: "New Computer Modern Math")
  set table(
    stroke: (x, y) => (top: if y == 0 { 0.8pt + ink } else if y == 1 { 0.5pt + ink } else { 0.4pt + rule }),
    inset: (x: 7pt, y: 5.5pt),
  )
  show table: it => block(stroke: (bottom: 0.8pt + ink), it)
  show table.cell.where(y: 0): set text(weight: "semibold")
  body
}

// One slide = one page. `kicker` is the small accent line above the title.
// Keep each H1 descriptive and brief (2–5 words); put the takeaway in the body.
#let slide-heading(body, size: 24pt) = {
  set block(above: 0pt, below: 0pt)
  show heading.where(level: 1): it => text(size: size, weight: "bold", tracking: -0.3pt, it.body)
  heading(level: 1, numbering: none, body)
}

#let slide(title: none, kicker: none, body) = {
  pagebreak(weak: true)
  [#metadata((kind: "slide", title: title)) <deck-slide>]
  if kicker != none {
    text(size: 10pt, weight: "semibold", fill: accent, tracking: 0.2pt, upper(kicker))
    v(-4pt)
  }
  slide-heading(title)
  v(6pt)
  body
}

// Title page with both logos.
#let title-slide(title: none, subtitle: none, kicker: none, meta: ()) = {
  [#metadata((kind: "title", title: title)) <deck-slide>]
  set page(footer: none, margin: (x: 1.8cm, top: 1.2cm, bottom: 1.2cm))
  grid(
    columns: (1fr, 1fr),
    align: (left + horizon, right + horizon),
    image("../intro/figures/epfl_logo.png", height: 0.9cm),
    image("../intro/figures/nii_logo.png", height: 0.9cm),
  )
  v(0.25cm)
  line(length: 100%, stroke: 0.6pt + rule)
  v(1.6cm)
  text(size: 10pt, weight: "semibold", fill: accent, tracking: 0.2pt, kicker)
  v(0.15cm)
  slide-heading(title, size: 34pt)
  v(0.1cm)
  block(width: 80%, text(size: 15pt, fill: muted, subtitle))
  v(1fr)
  grid(
    columns: (3cm, 1fr),
    row-gutter: 7pt,
    ..meta.map(((k, v)) => (text(size: 8.5pt, fill: muted, tracking: 0.8pt, upper(k)), text(size: 11pt, v))).flatten(),
  )
}

// Section divider: the question this part answers.
#let section(number, question, answer: none) = {
  pagebreak(weak: true)
  [#metadata((kind: "section", title: question)) <deck-slide>]
  set page(footer: none)
  v(1fr)
  text(size: 64pt, weight: "bold", fill: accent, str(number))
  v(-0.4cm)
  block(width: 85%, slide-heading(question, size: 28pt))
  if answer != none {
    v(0.2cm)
    block(width: 80%, text(size: 15pt, fill: muted, answer))
  }
  v(1.2fr)
}

// Shaded box for the one thing to remember on a slide.
#let note(title: none, body) = block(
  fill: soft,
  inset: (x: 11pt, y: 9pt),
  radius: 4pt,
  width: 100%,
  stroke: (left: 2.5pt + accent),
)[
  #set par(leading: 0.45em, spacing: 0.5em)
  #if title != none {
    text(size: 9pt, weight: "semibold", fill: accent, tracking: 1pt, upper(title))
    v(-2pt)
  }
  #body
]

// Source line pinned to the bottom of the slide body.
#let src(body) = {
  v(1fr)
  text(size: 9pt, fill: muted, body)
}

// A large number with a caption.
#let stat(value, caption) = block(width: 100%)[
  #text(size: 26pt, weight: "bold", tracking: -0.5pt, value)
  #v(-8pt)
  #text(size: 13.5pt, fill: muted, caption)
]

#let small(body) = text(size: 13.5pt, body)
#let dim(body) = text(fill: muted, body)

// Reusable cards keep the explanations and the diagrams at presentation size.
#let card(title, body, kicker: none, tone: accent, fill: soft, height: auto) = block(
  width: 100%, height: height, fill: fill, radius: 5pt,
  inset: 13pt, stroke: (left: 2.5pt + tone),
)[
  #set par(leading: 0.45em, spacing: 0.5em)
  #if kicker != none {
    text(size: 9pt, fill: tone, weight: "semibold", upper(kicker))
    v(4pt)
  }
  #text(size: 19pt, weight: "semibold", title)
  #v(7pt)
  #text(size: 16pt, body)
]

#let flow-node(title, body, tone: blue, fill: blue-soft) = block(
  width: 100%, fill: fill, radius: 5pt, inset: (x: 10pt, y: 10pt),
  stroke: 0.6pt + rule,
)[
  #set par(leading: 0.4em, spacing: 0.4em)
  #text(size: 16pt, fill: tone, weight: "semibold", title)
  #v(5pt)
  #text(size: 14pt, body)
]

#let arrow = text(size: 25pt, fill: muted)[→]
