import { useEffect, useRef, type PropsWithChildren } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

/**
 * MomentDissolve — client island that drives the niyyah → feed reveal.
 *
 * Phases (mirrors Circles/Moment/MomentPreviewView.NiyyahPhase):
 *   1. Hold niyyah overlay 1.2s after the section enters the viewport
 *   2. Overlay fades + scales to 0 over 0.8s (photoReveal → dissolving)
 *   3. Feed card fades up (+12px → 0) over 0.6s (settled)
 *
 * Respects prefers-reduced-motion: skips the timeline and shows the
 * end state (overlay hidden, feed visible).
 *
 * SPEC §7 target #2.
 */
export default function MomentDissolve({ children }: PropsWithChildren) {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;

    const niyyah = root.querySelector<HTMLElement>('[data-moment-layer="niyyah"]');
    const feed   = root.querySelector<HTMLElement>('[data-moment-layer="feed"]');
    if (!niyyah || !feed) return;

    // Reduced motion: jump to end state, skip timeline wiring.
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReduced) {
      gsap.set(niyyah, { opacity: 0 });
      gsap.set(feed,   { opacity: 1, y: 0 });
      return;
    }

    gsap.registerPlugin(ScrollTrigger);

    // Initial state
    gsap.set(niyyah, { opacity: 1, scale: 1 });
    gsap.set(feed,   { opacity: 0, y: 14 });

    const tl = gsap.timeline({
      paused: true,
      defaults: { ease: 'power2.inOut' },
    });

    // Phase 1 — hold
    tl.to(niyyah, { duration: 1.2, opacity: 1 });

    // Phase 2 — dissolve overlay
    tl.to(niyyah, { opacity: 0, scale: 0.98, duration: 0.8 });

    // Phase 3 — feed fades up (overlap by 0.2s so it feels like a dissolve)
    tl.to(feed, { opacity: 1, y: 0, duration: 0.6, ease: 'power2.out' }, '-=0.2');

    const trigger = ScrollTrigger.create({
      trigger: root,
      start: 'top 70%',
      once: false,
      onEnter: () => tl.restart(),
      onLeaveBack: () => {
        tl.pause(0);
        gsap.set(niyyah, { opacity: 1, scale: 1 });
        gsap.set(feed,   { opacity: 0, y: 14 });
      },
    });

    return () => {
      trigger.kill();
      tl.kill();
    };
  }, []);

  return (
    <div ref={rootRef} className="moment-dissolve-root">
      {children}
    </div>
  );
}
