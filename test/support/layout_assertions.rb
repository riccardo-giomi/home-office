module LayoutAssertions
  # WCAG 1.4.10 Reflow: no horizontal scrolling at 320 CSS px wide
  def assert_no_horizontal_scroll
    overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator overflow, :<=, 0, "the page is #{overflow}px wider than the viewport"
  end

  # WCAG 2.5.8 Target Size: interactive elements at least 24x24 CSS px
  def assert_target_sizes
    # Not rendered (display: none) or visually hidden until focused (the skip link) are not targets at rest
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("a[href], button, input:not([type=hidden]), select, textarea"))
        .filter(e => !e.classList.contains("sr-only") && e.getClientRects().length > 0)
        .map(e => { const r = e.getBoundingClientRect(); return {el: e.outerHTML.slice(0, 70), w: Math.round(r.width), h: Math.round(r.height)} })
        .filter(t => t.w < 24 || t.h < 24)
    JS
    assert_empty small, "targets smaller than 24x24: #{small.inspect}"
  end

  def assert_fits_small_screen
    assert_no_horizontal_scroll
    assert_target_sizes
  end
end
