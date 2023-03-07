import moment from "moment";

export const getDateNowUTC = () => {
  return moment.utc();
};

export const getNextDrawTime = (periodDays: number[], periodHourOfDays: number) => {
  let nextDrawTime = getDateNowUTC().set("hour", periodHourOfDays);
  const weekday = nextDrawTime.isoWeekday();

  let periodDay = 0;
  /*eslint no-constant-condition: ["error", { "checkLoops": false }]*/
  while (true) {
    if (weekday > periodDays[periodDay]) {
      nextDrawTime = nextDrawTime.add(periodDays[periodDay], "days");
      break;
    }

    periodDay = periodDay == periodDays.length ? 0 : periodDay + 1;
  }

  return nextDrawTime;
};
