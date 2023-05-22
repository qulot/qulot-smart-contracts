/**
 * Check period days is every day
 * @param periodDays
 * @returns
 */
export function isEveryDay(periodDays: number[] | undefined) {
  return (
    periodDays?.length &&
    periodDays.includes(0) &&
    periodDays.includes(1) &&
    periodDays.includes(2) &&
    periodDays.includes(3) &&
    periodDays.includes(4) &&
    periodDays.includes(5) &&
    periodDays.includes(6)
  );
}
