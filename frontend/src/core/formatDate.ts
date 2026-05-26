function formatDate(date: Date): string {

  const seconds = Math.round((Date.now() - date.getTime()) / 1000);
  const minutes = Math.round(                      seconds /   60);
  const hours   = Math.round(                      minutes /   60);
  const days    = Math.round(                        hours /   24);
  const weeks   = Math.round(                         days /    7);
  const months  = Math.round(                         days /   30);
  const years   = Math.round(                         days /  365);

  const relTime = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

  if (seconds < 60) {
    return relTime.format(-seconds, "second");
  } else if (minutes < 60) {
    return relTime.format(-minutes, "minute");
  } else if (hours < 24) {
    return relTime.format(  -hours,   "hour");
  } else if (days < 7) {
    return relTime.format(   -days,    "day");
  } else if (weeks < 5) {
    return relTime.format(  -weeks,   "week");
  } else if (months < 12) {
    return relTime.format( -months,  "month");
  } else {
    return relTime.format(  -years,   "year");
  }

}

export { formatDate };
