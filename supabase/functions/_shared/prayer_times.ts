// Adhan prayer time calculation — Muslim World League method
// Port of core Adhan algorithm. No external dependency.

export type PrayerName = "fajr" | "sunrise" | "dhuhr" | "asr" | "maghrib" | "isha";

export interface PrayerTimes {
  fajr: Date;
  sunrise: Date;
  dhuhr: Date;
  asr: Date;
  maghrib: Date;
  isha: Date;
}

// Muslim World League method angles
const MWL_FAJR_ANGLE = 18.0;
const MWL_ISHA_ANGLE = 17.0;

function toRad(deg: number) { return (deg * Math.PI) / 180; }
function toDeg(rad: number) { return (rad * 180) / Math.PI; }
function fixAngle(a: number) { return a - 360 * Math.floor(a / 360); }
function fixHour(a: number) { return a - 24 * Math.floor(a / 24); }

function julianDate(year: number, month: number, day: number): number {
  if (month <= 2) { year -= 1; month += 12; }
  const A = Math.floor(year / 100);
  const B = 2 - A + Math.floor(A / 4);
  return Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + day + B - 1524.5;
}

function sunPosition(jd: number) {
  const D = jd - 2451545.0;
  const g = fixAngle(357.529 + 0.98560028 * D);
  const q = fixAngle(280.459 + 0.98564736 * D);
  const L = fixAngle(q + 1.915 * Math.sin(toRad(g)) + 0.02 * Math.sin(toRad(2 * g)));
  const e = 23.439 - 0.00000036 * D;
  const RA = toDeg(Math.atan2(Math.cos(toRad(e)) * Math.sin(toRad(L)), Math.cos(toRad(L)))) / 15;
  const eqt = q / 15 - fixHour(RA);
  const decl = toDeg(Math.asin(Math.sin(toRad(e)) * Math.sin(toRad(L))));
  return { decl, eqt };
}

function hourAngle(angle: number, lat: number, decl: number): number {
  const num = -Math.sin(toRad(angle)) - Math.sin(toRad(lat)) * Math.sin(toRad(decl));
  const den = Math.cos(toRad(lat)) * Math.cos(toRad(decl));
  return toDeg(Math.acos(num / den)) / 15;
}

export function getPrayerTimes(lat: number, lng: number, date: Date): PrayerTimes {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();
  const jd = julianDate(year, month, day) - lng / (15 * 24);
  const { decl, eqt } = sunPosition(jd);

  const midday = fixHour(12 - eqt);

  const fajrHour = midday - hourAngle(MWL_FAJR_ANGLE, lat, decl);
  const sunriseHour = midday - hourAngle(0.8333, lat, decl);
  const dhuhrHour = midday + 0.0;
  // Standard (Shafi) asr: shadow length factor 1
  const asrAngle = toDeg(Math.atan(1 + Math.tan(toRad(Math.abs(lat - decl)))));
  const asrHour = midday + hourAngle(-asrAngle, lat, decl);
  const maghribHour = midday + hourAngle(0.8333, lat, decl);
  const ishaHour = midday + hourAngle(MWL_ISHA_ANGLE, lat, decl);

  function toUTCDate(utcHours: number): Date {
    const h = Math.floor(utcHours);
    const m = Math.round((utcHours - h) * 60);
    return new Date(Date.UTC(year, month - 1, day, h, m, 0));
  }

  return {
    fajr: toUTCDate(fajrHour),
    sunrise: toUTCDate(sunriseHour),
    dhuhr: toUTCDate(dhuhrHour),
    asr: toUTCDate(asrHour),
    maghrib: toUTCDate(maghribHour),
    isha: toUTCDate(ishaHour),
  };
}
