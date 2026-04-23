import { useEffect, useRef, type PropsWithChildren } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

/**
 * NoorBeadFill — client island that animates the Noor ring + streak beads
 * in the HabitDetailShell mockup.
 *
 * On scroll into view:
 *   1. Ring stroke-dashoffset animates from CIRC (hidden) → target
 *      (set in CSS custom property --noor-target on the element) over
 *      1.2s ease power2.inOut
 *   2. Beads fill left-to-right on a 0.12s stagger, each swapping from
 *      muted border → gold fill with a tiny scale pop (1 → 1.15 → 1, 0.3s)
 *
 * Respects prefers-reduced-motion: jumps to end state immediately
 * (ring at target offset, all beads filled) and skips the timeline.
 *
 * Replays on onLeaveBack so scrolling up + back down re-plays the ritual,
 * matching the MomentDissolve behavior.
 *
 * SPEC §7 target #3.
 */
export default function NoorBeadFill({ children }: PropsWithChildren) {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;

    const ring = root.querySelector<SVGCircleElement>('[data-noor-ring]');
    const beads = Array.from(
      root.querySelectorAll<HTMLElement>('[data-bead-index]')
    ).sort((a, b) => {
      const ai = Number(a.dataset.beadIndex ?? 0);
      const bi = Number(b.dataset.beadIndex ?? 0);
      return ai - bi;
    });

    if (!ring || beads.length === 0) return;

    // Read CIRC from the initial dashoffset attribute (SSR sets it) and
    // the target from the CSS custom property on the element's style.
    const startOffset = Number(
      ring.getAttribute('stroke-dashoffset') ?? '0'
    );
    const cssTarget = getComputedStyle(ring).getPropertyValue('--noor-target').trim();
    const targetOffset = cssTarget ? parseFloat(cssTarget) : startOffset * 0.4;

    const fillBead = (bead: HTMLElement) => {
      bead.dataset.filled = 'true';
    };
    const clearBead = (bead: HTMLElement) => {
      delete bead.dataset.filled;
    };

    const prefersReduced = window.matchMedia(
      '(prefers-reduced-motion: reduce)'
    ).matches;

    if (prefersReduced) {
      gsap.set(ring, { attr: { 'stroke-dashoffset': targetOffset } });
      for (const b of beads) fillBead(b);
      return;
    }

    gsap.registerPlugin(ScrollTrigger);

    // Initial state
    gsap.set(ring, { attr: { 'stroke-dashoffset': startOffset } });
    for (const b of beads) {
      clearBead(b);
      gsap.set(b, { scale: 1 });
    }

    const tl = gsap.timeline({ paused: true });

    // Phase 1 — ring fills
    tl.to(ring, {
      attr: { 'stroke-dashoffset': targetOffset },
      duration: 1.2,
      ease: 'power2.inOut',
    });

    // Phase 2 — beads stagger fill with a tiny pop
    beads.forEach((bead, i) => {
      const at = `-=${1.2 - i * 0.12}`;
      // Flip to gold
      tl.call(() => fillBead(bead), undefined, at);
      // Scale pop
      tl.to(
        bead,
        {
          keyframes: [
            { scale: 1.15, duration: 0.14, ease: 'power2.out' },
            { scale: 1,    duration: 0.16, ease: 'power2.inOut' },
          ],
        },
        at
      );
    });

    const trigger = ScrollTrigger.create({
      trigger: root,
      start: 'top 75%',
      once: false,
      onEnter: () => tl.restart(),
      onLeaveBack: () => {
        tl.pause(0);
        gsap.set(ring, { attr: { 'stroke-dashoffset': startOffset } });
        for (const b of beads) {
          clearBead(b);
          gsap.set(b, { scale: 1 });
        }
      },
    });

    return () => {
      trigger.kill();
      tl.kill();
    };
  }, []);

  return (
    <div ref={rootRef} className="noor-bead-fill-root">
      {children}
    </div>
  );
}
