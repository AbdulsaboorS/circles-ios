import { useEffect, useRef, type PropsWithChildren } from 'react';

/**
 * ScrollReveal — reusable client island that fades its direct children up
 * (+16px → 0, opacity 0 → 1) as they enter the viewport. Staggers siblings
 * with `stagger` ms between each.
 *
 * Vanilla IntersectionObserver (no GSAP here — SPEC §7 target #4 explicitly
 * calls for "CSS + IntersectionObserver vanilla JS" to keep JS footprint small).
 *
 * prefers-reduced-motion: reveal instantly (end state, no transform).
 *
 * Hydrate via `client:visible` so the observer doesn't spin up until the
 * section is near the viewport.
 */
type Props = PropsWithChildren<{
  /** Delay in ms between each child's reveal. Default 100ms. */
  stagger?: number;
  /** Root margin passed to IntersectionObserver. Default triggers at ~80% viewport. */
  rootMargin?: string;
  /** Replay when scrolled out + back (like the Moment timeline). Default false. */
  replay?: boolean;
}>;

export default function ScrollReveal({
  children,
  stagger = 100,
  rootMargin = '0px 0px -20% 0px',
  replay = false,
}: Props) {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;

    // Collect direct children as the reveal targets. Falls back to all
    // descendants with [data-reveal] if the caller opted into finer control.
    const explicit = root.querySelectorAll<HTMLElement>('[data-reveal]');
    const targets: HTMLElement[] =
      explicit.length > 0
        ? Array.from(explicit)
        : (Array.from(root.children) as HTMLElement[]);

    if (targets.length === 0) return;

    const prefersReduced = window.matchMedia(
      '(prefers-reduced-motion: reduce)'
    ).matches;

    // Initial state: hidden + nudged down. Skip for reduced motion.
    if (!prefersReduced) {
      for (const el of targets) {
        el.style.opacity = '0';
        el.style.transform = 'translateY(16px)';
        el.style.transition =
          'opacity 600ms ease-out, transform 600ms ease-out';
        el.style.willChange = 'opacity, transform';
      }
    }

    const reveal = (el: HTMLElement, index: number) => {
      const delay = index * stagger;
      window.setTimeout(() => {
        el.style.opacity = '1';
        el.style.transform = 'translateY(0)';
      }, delay);
    };

    const hide = (el: HTMLElement) => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(16px)';
    };

    if (prefersReduced) {
      // End state immediately — skip the observer entirely.
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const el = entry.target as HTMLElement;
          const index = targets.indexOf(el);
          if (index === -1) continue;

          if (entry.isIntersecting) {
            reveal(el, index);
            if (!replay) {
              observer.unobserve(el);
            }
          } else if (replay) {
            hide(el);
          }
        }
      },
      { rootMargin, threshold: 0.05 }
    );

    for (const el of targets) {
      observer.observe(el);
    }

    return () => observer.disconnect();
  }, [stagger, rootMargin, replay]);

  return <div ref={rootRef} className="scroll-reveal-root">{children}</div>;
}
